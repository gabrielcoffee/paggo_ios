import Foundation

/// Máscara de CNPJ/CPF baseada no comprimento — paridade com `cnpjOrCpfMask` do web.
/// 14 dígitos → `XX.XXX.XXX/XXXX-XX`; 11 → `XXX.XXX.XXX-XX`; qualquer outro tamanho → texto cru.
/// Idempotente: remove a pontuação existente antes de reaplicar, então formatar duas vezes é seguro.
extension String {
    var cnpjOrCpfMasked: String {
        let d = filter(\.isNumber)
        func mask(_ pattern: String) -> String {
            var o = ""
            var it = d.makeIterator()
            for t in pattern {
                if t == "#" {
                    guard let c = it.next() else { break }
                    o.append(c)
                } else {
                    o.append(t)
                }
            }
            return o
        }
        switch d.count {
        case 14: return mask("##.###.###/####-##")
        case 11: return mask("###.###.###-##")
        default: return self
        }
    }
}
