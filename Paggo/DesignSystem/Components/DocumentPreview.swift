import PDFKit
import SwiftUI
import UIKit

// Preview inline de documentos (NF-e / anexos) — paridade com o
// `document-preview.tsx` do blue: PDF vira thumbnail da página 1, imagem
// renderiza direto; toque abre o viewer em tela cheia com zoom + share.
// Arquivos servidos pelo CDN público `files.paggo.ai` (fetch sem headers de auth).

// MARK: - Resolução de URL + tipo (paridade com blue getUrl / normalizeMimeType)

enum DocumentFile {
    static let cdnBase = "https://files.paggo.ai"

    enum Kind: Sendable { case pdf, image }

    /// Espelha o `getUrl` do blue: chave com `/` inicial ou relativa → prefixa o CDN;
    /// URL absoluta passa direto. Só resolve chaves com mais de 5 caracteres (paridade web).
    static func resolveURL(_ raw: String?) -> URL? {
        guard let raw, raw.count > 5 else { return nil }
        if raw.hasPrefix("http://") || raw.hasPrefix("https://") { return URL(string: raw) }
        let path = raw.hasPrefix("/") ? raw : "/\(raw)"
        if let url = URL(string: cdnBase + path) { return url }
        // Chaves com espaço/acento: percent-encode preservando '/'.
        guard let encoded = path.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) else {
            return nil
        }
        return URL(string: cdnBase + encoded)
    }

    /// Espelha `normalizeMimeType` (paggo-core-utils): extensão após o último `.`/`_` do último
    /// segmento (sem query/fragment). pdf → PDF; jpg/jpeg/png/gif/webp → imagem; xml/svg → sem
    /// preview (o iOS não renderiza SVG nativamente); desconhecida → PDF (default do helper).
    static func kind(of raw: String?) -> Kind? {
        guard let raw, raw.count > 5 else { return nil }
        let sanitized = raw.components(separatedBy: CharacterSet(charactersIn: "?#")).first ?? raw
        let lastSegment = sanitized.components(separatedBy: "/").last ?? sanitized
        let ext = lastSegment.lowercased()
            .components(separatedBy: CharacterSet(charactersIn: "._")).last ?? ""
        switch ext {
        case "pdf": return .pdf
        case "jpg", "jpeg", "png", "gif", "webp": return .image
        case "xml", "svg": return nil
        default: return .pdf
        }
    }
}

// MARK: - Caches (bytes por URL + thumbnails renderizados)

/// Bytes do arquivo por URL, com deduplicação de downloads em voo. CDN público — URLSession
/// pura, sem os headers do APIClient.
actor DocumentDataCache {
    static let shared = DocumentDataCache()

    private let cache = NSCache<NSURL, NSData>()
    private var inFlight: [URL: (task: Task<Data, Error>, waiters: Int)] = [:]

    init() { cache.totalCostLimit = 48 * 1024 * 1024 }

    func data(for url: URL) async throws -> Data {
        if let hit = cache.object(forKey: url as NSURL) { return hit as Data }
        let task: Task<Data, Error>
        if let existing = inFlight[url] {
            task = existing.task
            inFlight[url] = (task, existing.waiters + 1)
        } else {
            task = Task {
                let (data, response) = try await URLSession.shared.data(from: url)
                guard let http = response as? HTTPURLResponse,
                      (200..<300).contains(http.statusCode) else {
                    throw URLError(.badServerResponse)
                }
                return data
            }
            inFlight[url] = (task, 1)
        }
        defer { removeWaiter(url: url, task: task) }
        // Cancelamento do chamador (a `.task` da row saiu de cena) cancela o download
        // subjacente quando este era o único interessado — senão os outros waiters seguem.
        let data = try await withTaskCancellationHandler {
            try await task.value
        } onCancel: {
            Task { await self.cancelIfSoleWaiter(url: url, task: task) }
        }
        cache.setObject(data as NSData, forKey: url as NSURL, cost: data.count)
        return data
    }

    private func removeWaiter(url: URL, task: Task<Data, Error>) {
        guard let entry = inFlight[url], entry.task == task else { return }
        if entry.waiters <= 1 {
            inFlight[url] = nil
        } else {
            inFlight[url] = (entry.task, entry.waiters - 1)
        }
    }

    private func cancelIfSoleWaiter(url: URL, task: Task<Data, Error>) {
        guard let entry = inFlight[url], entry.task == task, entry.waiters <= 1 else { return }
        task.cancel()
        inFlight[url] = nil   // libera a chave — um retry futuro inicia um download novo
    }
}

/// Thumbnails já renderizados (página 1 de PDF / imagem decodificada) — evita re-render ao
/// trocar de aba (o conteúdo das abas do detalhe é destruído e recriado).
@MainActor
enum DocumentThumbnailCache {
    static let cache = NSCache<NSURL, UIImage>()
}

// MARK: - Card de preview

/// Card de preview do documento: fundo branco (papel), thumbnail alinhado ao topo, skeleton
/// durante o carregamento. Falha vira um card compacto de retry (toque tenta de novo) — a view
/// permanece montada para não derrubar o `fullScreenCover` se o viewer estiver aberto. Toque
/// no preview abre o viewer em tela cheia.
struct DocumentPreview: View {
    let rawUrl: String?
    var height: CGFloat = 240

    @State private var thumbnail: UIImage?
    @State private var failed = false
    @State private var showViewer = false
    /// URL que produziu o estado atual — se a row for reutilizada com outro documento,
    /// o `.task` detecta a troca e zera thumbnail/failed antes de recarregar.
    @State private var loadedURL: URL?
    /// Incrementado no toque de retry para re-disparar o `.task(id:)`.
    @State private var attempt = 0

    init(rawUrl: String?, height: CGFloat = 240, previewThumbnail: UIImage? = nil) {
        self.rawUrl = rawUrl
        self.height = height
        _thumbnail = State(initialValue: previewThumbnail)
        _loadedURL = State(initialValue: DocumentFile.resolveURL(rawUrl))
    }

    private var url: URL? { DocumentFile.resolveURL(rawUrl) }
    private var kind: DocumentFile.Kind? { DocumentFile.kind(of: rawUrl) }

    private struct LoadKey: Equatable {
        let rawUrl: String?
        let attempt: Int
    }

    var body: some View {
        if let url, let kind {
            Button {
                if failed {
                    failed = false
                    attempt += 1   // muda o id do .task → nova tentativa de carregamento
                } else {
                    showViewer = true
                }
            } label: {
                if failed {
                    retryCard
                } else {
                    card
                }
            }
            .buttonStyle(.plain)
            .task(id: LoadKey(rawUrl: rawUrl, attempt: attempt)) {
                await loadThumbnail(url: url, kind: kind)
            }
            .fullScreenCover(isPresented: $showViewer) {
                DocumentViewerView(url: url, kind: kind)
            }
        }
    }

    private var card: some View {
        ZStack(alignment: .top) {
            Color.white
            if let thumbnail {
                Image(uiImage: thumbnail)
                    .resizable()
                    .scaledToFit()
            } else {
                RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                    .fill(Theme.surfaceHigh.opacity(0.5))
                    .shimmer()
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: height)
        .clipShape(RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                .stroke(Theme.separator, lineWidth: 1)
        }
        .contentShape(RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
        .accessibilityLabel("Preview do documento")
    }

    /// Estado de falha: card compacto com affordance de retry — não colapsa (mantém o host do
    /// `fullScreenCover` montado) e a falha não é permanente.
    private var retryCard: some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: "arrow.clockwise")
                .font(.system(size: 14, weight: .medium))
            Text("Falha ao carregar o preview — toque para tentar novamente")
                .font(.brand(.caption))
                .multilineTextAlignment(.leading)
        }
        .foregroundStyle(Theme.textTertiary)
        .frame(maxWidth: .infinity)
        .padding(.vertical, Spacing.md)
        .padding(.horizontal, Spacing.md)
        .background(Theme.surfaceHigh.opacity(0.5),
                    in: RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                .stroke(Theme.separator, lineWidth: 1)
        }
        .contentShape(RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
        .accessibilityLabel("Falha ao carregar o preview do documento. Toque para tentar novamente")
    }

    private func loadThumbnail(url: URL, kind: DocumentFile.Kind) async {
        if loadedURL != url {
            // Row reutilizada com outro documento: o estado anterior não vale para esta URL.
            thumbnail = nil
            failed = false
            loadedURL = url
        }
        guard thumbnail == nil, !failed else { return }
        if let cached = DocumentThumbnailCache.cache.object(forKey: url as NSURL) {
            thumbnail = cached
            return
        }
        do {
            let data = try await DocumentDataCache.shared.data(for: url)
            guard !Task.isCancelled else { return }
            // Render fora da MainActor; o handler encaminha o cancelamento do `.task` da row
            // para a task destacada (PDFKit não interrompe um render em curso, mas evita
            // começar um novo e libera o waiter).
            let renderTask = Task.detached(priority: .userInitiated) { () -> UIImage? in
                guard !Task.isCancelled else { return nil }
                switch kind {
                case .pdf:
                    guard let document = PDFDocument(data: data),
                          let page = document.page(at: 0) else { return nil }
                    let bounds = page.bounds(for: .mediaBox)
                    guard bounds.width > 0, bounds.height > 0 else { return nil }
                    // Escala 3.5 (paridade com o blue), limitada a ~1400px de largura.
                    let scale = min(3.5, 1400 / bounds.width)
                    let size = CGSize(width: bounds.width * scale, height: bounds.height * scale)
                    return page.thumbnail(of: size, for: .mediaBox)
                case .image:
                    guard let image = UIImage(data: data) else { return nil }
                    return image.preparingForDisplay() ?? image
                }
            }
            let rendered = await withTaskCancellationHandler {
                await renderTask.value
            } onCancel: {
                renderTask.cancel()
            }
            guard !Task.isCancelled else { return }
            if let rendered {
                DocumentThumbnailCache.cache.setObject(rendered, forKey: url as NSURL)
                thumbnail = rendered
            } else {
                failed = true
            }
        } catch {
            guard !Task.isCancelled else { return }   // cancelado ≠ falha — não marca o card
            failed = true   // recuperável — o card vira o affordance de retry
        }
    }
}

// MARK: - Viewer em tela cheia

/// Viewer do documento: PDFView (autoScales) com zoom/pan; imagens viram uma página de PDF
/// (`PDFPage(image:)`) e ganham o mesmo tratamento. Share via ShareSheet.
struct DocumentViewerView: View {
    let url: URL
    let kind: DocumentFile.Kind

    @Environment(\.dismiss) private var dismiss
    @State private var data: Data?
    @State private var failed = false
    @State private var shareURL: URL?

    var body: some View {
        NavigationStack {
            Group {
                if let data {
                    DocumentPDFView(data: data, kind: kind)
                        .ignoresSafeArea(edges: .bottom)
                } else if failed {
                    VStack(spacing: Spacing.md) {
                        Image(systemName: "doc.questionmark")
                            .font(.system(size: 36, weight: .light))
                            .foregroundStyle(Theme.textTertiary)
                        Text("Não foi possível carregar o documento")
                            .font(.brand(.subheadline))
                            .foregroundStyle(Theme.textTertiary)
                    }
                } else {
                    ProgressView().tint(Theme.accent)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Theme.base)
            .navigationTitle("Documento")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                    }
                    .accessibilityLabel("Fechar")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        share()
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                    }
                    .disabled(data == nil)
                    .accessibilityLabel("Compartilhar")
                }
            }
            .task { await load() }
            .sheet(item: $shareURL) { fileURL in
                ShareSheet(items: [fileURL])
                    .presentationDetents([.medium, .large])
            }
        }
    }

    private func load() async {
        guard data == nil else { return }
        do {
            data = try await DocumentDataCache.shared.data(for: url)
        } catch {
            failed = true
        }
    }

    /// Compartilha o arquivo local (nome real preservado) — cai para a URL remota se a escrita falhar.
    private func share() {
        guard let data else { return }
        let name = url.lastPathComponent.isEmpty ? "documento.pdf" : url.lastPathComponent
        let destination = FileManager.default.temporaryDirectory.appendingPathComponent(name)
        do {
            try data.write(to: destination, options: .atomic)
            shareURL = destination
        } catch {
            shareURL = url
        }
    }
}

/// PDFView (PDFKit) para SwiftUI — o documento é montado no `makeUIView` (MainActor), a partir
/// dos bytes já baixados. Imagem vira uma página única de PDF (zoom/pan de graça).
private struct DocumentPDFView: UIViewRepresentable {
    let data: Data
    let kind: DocumentFile.Kind

    func makeUIView(context: Context) -> PDFView {
        let view = PDFView()
        view.autoScales = true
        view.backgroundColor = .clear
        view.document = makeDocument()
        return view
    }

    func updateUIView(_ view: PDFView, context: Context) {}

    private func makeDocument() -> PDFDocument? {
        switch kind {
        case .pdf:
            return PDFDocument(data: data)
        case .image:
            guard let image = UIImage(data: data), let page = PDFPage(image: image) else {
                return nil
            }
            let document = PDFDocument()
            document.insert(page, at: 0)
            return document
        }
    }
}

// MARK: - Previews

#Preview("Card — carregado / skeleton") {
    let sample = {
        let size = CGSize(width: 320, height: 452)
        return UIGraphicsImageRenderer(size: size).image { ctx in
            UIColor.white.setFill()
            ctx.fill(CGRect(origin: .zero, size: size))
            UIColor(white: 0.2, alpha: 1).setFill()
            ctx.fill(CGRect(x: 24, y: 28, width: 140, height: 14))
            UIColor(white: 0.75, alpha: 1).setFill()
            for row in 0..<9 {
                ctx.fill(CGRect(x: 24, y: 70 + row * 34, width: 272, height: 8))
            }
        }
    }()
    ScrollView {
        VStack(spacing: Spacing.lg) {
            DocumentPreview(rawUrl: "/documents/nf-00012345.pdf", previewThumbnail: sample)
            DocumentPreview(rawUrl: "documents/nf-00067890.pdf")   // skeleton (fetch em voo)
        }
        .padding(Spacing.lg)
    }
    .background(Theme.base)
}
