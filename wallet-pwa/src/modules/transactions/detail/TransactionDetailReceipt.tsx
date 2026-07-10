import { useMemo } from 'react';

import {
  Page,
  Text,
  View,
  Document,
  StyleSheet,
  Svg,
  Path,
  Font,
  Circle,
} from '@react-pdf/renderer';
import { toUpper } from 'lodash';
import { DateTime } from 'luxon';

import {
  CELCOIN_BANK,
  PAGGO_LEGAL_NAME,
  PAGGO_TAX_ID,
  getBankNameFromISPB,
} from '@paggo/constants';
import {
  capitalizeString,
  cnpjValid,
  formatNumberReal,
  formatToCPFOrCNPJ,
  padZero,
} from '@paggo/core-utils';

import type { WALLET_PAYMENT_METHODS } from '@prisma/client';
import type { Style } from '@react-pdf/types';

type TransactionDetailPartyProps = {
  label: string;
  value?: string;
  style?: Style | Style[] | undefined;
};

type SectionProps = {
  name: string;
  icon: JSX.Element;
};

type FooterProps = {
  isPix: boolean;
  isBarcode: boolean;
  transactionId?: string;
  digitableLine?: string;
  authenticationData?: string;
};

type TransactionDetailReceiptProps = {
  transaction?: {
    id: string;
    date: string;
    amount: number;
    status: string;
    method: WALLET_PAYMENT_METHODS;
    endToEndId?: string;
    digitableLine?: string;
    authenticationData?: string;
    dueDate?: Date;
    fineAmount?: number;
    discountAmount?: number;
    interestAmount?: number;
    assignor?: string;
    creditParty: {
      bankCode?: string;
      branch?: string;
      accountNumber?: string;
      receiverLegalName: string;
      receiverDocumentNumber: string;
    };
    debitParty: {
      accountNumber: string;
      receiverLegalName: string;
      receiverDocumentNumber: string;
    };
  };
};

Font.register({
  family: 'Poligon',
  fonts: [
    {
      src: '/assets/fonts/hiIBIGlH.otf',
      fontStyle: 'normal',
      fontWeight: 100,
    },
    {
      src: '/assets/fonts/flVlHJcA.otf',
      fontStyle: 'italic',
      fontWeight: 100,
    },
    {
      src: '/assets/fonts/gzOAojWl.otf',
      fontStyle: 'normal',
      fontWeight: 200,
    },
    {
      src: '/assets/fonts/NbqQMXps.otf',
      fontStyle: 'italic',
      fontWeight: 200,
    },
    {
      src: '/assets/fonts/qQDAvRfq.otf',
      fontStyle: 'normal',
      fontWeight: 300,
    },
    {
      src: '/assets/fonts/WjagMeJX.otf',
      fontStyle: 'italic',
      fontWeight: 300,
    },
    {
      src: '/assets/fonts/oNTTsdML.otf',
      fontStyle: 'normal',
      fontWeight: 400,
    },
    {
      src: '/assets/fonts/ErRYWWpk.otf',
      fontStyle: 'italic',
      fontWeight: 400,
    },
    {
      src: '/assets/fonts/WynQfnsK.otf',
      fontStyle: 'normal',
      fontWeight: 500,
    },
    {
      src: '/assets/fonts/sBPUSXBe.otf',
      fontStyle: 'italic',
      fontWeight: 500,
    },
    {
      src: '/assets/fonts/SZlwaSlr.otf',
      fontStyle: 'normal',
      fontWeight: 600,
    },
    {
      src: '/assets/fonts/VTwClNDu.otf',
      fontStyle: 'italic',
      fontWeight: 600,
    },
    {
      src: '/assets/fonts/dOmMUSzt.otf',
      fontStyle: 'normal',
      fontWeight: 700,
    },
    {
      src: '/assets/fonts/yMDzMYNR.otf',
      fontStyle: 'italic',
      fontWeight: 700,
    },
    {
      src: '/assets/fonts/TYSovtRg.otf',
      fontStyle: 'normal',
      fontWeight: 800,
    },
    {
      src: '/assets/fonts/mtglZJKL.otf',
      fontStyle: 'italic',
      fontWeight: 800,
    },
  ],
});

const colors = {
  white: '#ffffff',
  black: '#000000',
  gray: {
    100: '#fafafa',
    200: '#f2eeed',
    300: '#e1dbda',
    500: '#746f6e',
    600: '#686262',
    900: '#0e0d0d',
  },
};

const styles = StyleSheet.create({
  page: {
    paddingTop: 16,
    flexDirection: 'column',
    backgroundColor: colors.white,
    fontFamily: 'Poligon',
    fontStyle: 'normal',
  },
  pageSize: {
    width: 500,
  },
  headerContainer: {
    width: '100%',
    flexGrow: 1,
    marginBottom: '8px',
    paddingHorizontal: 16,
  },
  logoContainer: {
    marginBottom: 30,
  },
  containerScreen: {
    width: '100vw',
  },
  transactionDetailPartyContainer: {
    display: 'flex',
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
    width: '100%',
    marginTop: 16,
    marginBottom: 8,
  },
  transactionDetailPartySectionContainer: {
    flexDirection: 'column',
    width: '100%',
    marginBottom: 24,
  },
  transactionDetailPartySection: {
    flexDirection: 'column',
    width: '100%',
    marginBottom: 24,
    paddingHorizontal: 16,
  },
  semanticTypographyDisplaySmall: {
    fontWeight: 400,
    fontSize: '24px',
  },
  semanticTypographyOverheadMid: {
    fontWeight: 300,
    fontSize: '16px',
  },
  semanticTypographyBody: {
    fontSize: '17px',
    fontWeight: 400,
    width: '100%',
  },
  semanticTypographyTitleBig: {
    fontSize: '17px',
    fontWeight: 600,
    overflow: 'hidden',
    textOverflow: 'ellipsis',
  },
  semanticTypographyTitle: {
    fontSize: '14px',
    fontWeight: 500,
    overflow: 'hidden',
    textOverflow: 'ellipsis',
    textAlign: 'left',
  },
  sectionBorder: {
    display: 'flex',
    flexDirection: 'row',
    height: '1px',
    flexGrow: 1,
    backgroundColor: colors.gray[200],
  },
  sectionContainer: {
    display: 'flex',
    flexDirection: 'row',
    gap: 16,
    backgroundColor: colors.gray[100],
    alignItems: 'center',
    padding: '16px 16px 8px',
  },
  sectionMarginIcon: {
    marginTop: -4,
  },
  footerContainer: {
    width: '100%',
    display: 'flex',
    flexDirection: 'column',
    justifyContent: 'flex-start',
    gap: 8,
    paddingHorizontal: 16,
    paddingVertical: 24,
    backgroundColor: colors.gray[300],
  },
  paddingHorizontalMid: {
    paddingHorizontal: 16,
  },
  marginBottomMid: {
    marginBottom: 16,
  },
  marginBottomSmall: {
    marginBottom: 4,
  },
  truncate: {
    overflow: 'hidden',
    textOverflow: 'ellipsis',
  },
  amountMargin: {
    marginBottom: 8,
    marginTop: 16,
  },
  paymentTypeMargin: {
    marginBottom: 16,
    marginTop: 8,
  },
});

const PaggoLogo = () => (
  <Svg fill="none" viewBox="0 0 114 24" width={108}>
    <Path
      fill={colors.black}
      fillRule="evenodd"
      d="M15.516 15.2l3.103-3.104-9.31-9.31L0 12.096l3.103 3.103a8.777 8.777 0 0112.413 0z"
    />
    <Path
      fill={colors.black}
      d="M33.501 17.143c-1.267 0-2.396-.263-3.387-.789a6.27 6.27 0 01-2.35-2.228c-.553-.937-.83-2-.83-3.189V6.206c0-1.189.289-2.252.865-3.189a6.012 6.012 0 012.35-2.194C31.139.274 32.257 0 33.5 0 35 0 36.347.389 37.545 1.166c1.22.754 2.177 1.783 2.868 3.085.714 1.28 1.071 2.732 1.071 4.355 0 1.6-.357 3.051-1.07 4.354a7.975 7.975 0 01-2.87 3.051c-1.197.755-2.545 1.132-4.043 1.132zm-.622-3.566c.922 0 1.728-.206 2.42-.617a4.439 4.439 0 001.658-1.783c.415-.754.622-1.623.622-2.606 0-.982-.207-1.851-.622-2.605a4.209 4.209 0 00-1.659-1.749c-.691-.434-1.497-.651-2.419-.651-.922 0-1.74.217-2.454.651a4.209 4.209 0 00-1.659 1.749c-.391.754-.587 1.623-.587 2.605 0 .983.196 1.852.587 2.606a4.439 4.439 0 001.66 1.783c.714.411 1.531.617 2.453.617zm-8.26 10.08V.343h3.802v4.423l-.657 4.011.657 3.977v10.903h-3.802zM49.885 17.143c-1.497 0-2.857-.377-4.078-1.132-1.198-.754-2.154-1.771-2.868-3.051-.691-1.303-1.037-2.754-1.037-4.354 0-1.623.346-3.075 1.037-4.355.714-1.302 1.67-2.331 2.868-3.085C47.028.389 48.387 0 49.885 0c1.267 0 2.385.274 3.352.823a6.012 6.012 0 012.35 2.194c.577.937.865 2 .865 3.189v4.731c0 1.189-.288 2.252-.864 3.189a6.008 6.008 0 01-2.316 2.228c-.99.526-2.12.789-3.387.789zm.622-3.566c1.406 0 2.535-.468 3.387-1.406.876-.937 1.314-2.137 1.314-3.6 0-.982-.196-1.851-.588-2.605a4.208 4.208 0 00-1.659-1.749c-.691-.434-1.51-.651-2.454-.651-.921 0-1.74.217-2.453.651-.692.412-1.245.994-1.66 1.749-.391.754-.587 1.623-.587 2.605 0 .983.196 1.852.588 2.606a4.78 4.78 0 001.658 1.783c.715.411 1.533.617 2.454.617zm4.459 3.223v-4.423l.656-4.011-.657-3.977V.343h3.802V16.8h-3.802zM68.17 24c-1.75 0-3.283-.32-4.596-.96-1.314-.617-2.373-1.497-3.18-2.64l2.489-2.469c.668.823 1.428 1.44 2.28 1.852.853.411 1.878.617 3.076.617 1.498 0 2.684-.389 3.56-1.166.875-.754 1.313-1.794 1.313-3.12V12.07l.657-3.635-.657-3.668V.343h3.802v15.771c0 1.577-.369 2.949-1.106 4.115-.737 1.188-1.763 2.114-3.076 2.777-1.313.663-2.834.994-4.562.994zm-.173-7.543c-1.474 0-2.81-.354-4.009-1.063-1.175-.731-2.108-1.725-2.799-2.983-.668-1.257-1.002-2.662-1.002-4.217 0-1.554.334-2.948 1.002-4.183a7.766 7.766 0 012.8-2.914C65.185.366 66.522 0 67.996 0c1.314 0 2.466.263 3.456.789a5.768 5.768 0 012.316 2.194c.553.914.83 1.988.83 3.223v4.045c0 1.212-.289 2.286-.865 3.223a5.768 5.768 0 01-2.315 2.195c-.99.525-2.131.788-3.422.788zm.76-3.566c.922 0 1.729-.194 2.42-.582a3.98 3.98 0 001.59-1.612c.391-.708.587-1.531.587-2.468 0-.938-.196-1.749-.587-2.435a3.927 3.927 0 00-1.59-1.645c-.691-.389-1.498-.583-2.42-.583-.92 0-1.739.194-2.453.583a4.151 4.151 0 00-1.624 1.645c-.392.686-.588 1.497-.588 2.435 0 .914.196 1.725.588 2.434a4.152 4.152 0 001.624 1.646c.714.388 1.532.582 2.454.582zM86.32 24c-1.75 0-3.282-.32-4.596-.96-1.313-.617-2.373-1.497-3.18-2.64l2.49-2.469c.667.823 1.428 1.44 2.28 1.852.853.411 1.878.617 3.076.617 1.498 0 2.684-.389 3.56-1.166.875-.754 1.313-1.794 1.313-3.12V12.07l.657-3.635-.657-3.668V.343h3.802v15.771c0 1.577-.369 2.949-1.106 4.115-.738 1.188-1.763 2.114-3.076 2.777-1.313.663-2.834.994-4.562.994zm-.172-7.543c-1.474 0-2.81-.354-4.009-1.063-1.175-.731-2.108-1.725-2.8-2.983-.667-1.257-1.001-2.662-1.001-4.217 0-1.554.334-2.948 1.002-4.183a7.766 7.766 0 012.8-2.914C83.336.366 84.673 0 86.147 0c1.313 0 2.465.263 3.456.789a5.768 5.768 0 012.316 2.194c.553.914.83 1.988.83 3.223v4.045c0 1.212-.289 2.286-.865 3.223a5.769 5.769 0 01-2.315 2.195c-.991.525-2.132.788-3.422.788zm.76-3.566c.922 0 1.728-.194 2.42-.582a3.978 3.978 0 001.59-1.612c.391-.708.587-1.531.587-2.468 0-.938-.196-1.749-.588-2.435a3.926 3.926 0 00-1.59-1.645c-.69-.389-1.497-.583-2.418-.583-.922 0-1.74.194-2.454.583a4.15 4.15 0 00-1.625 1.645c-.391.686-.587 1.497-.587 2.435 0 .914.196 1.725.587 2.434a4.151 4.151 0 001.625 1.646c.714.388 1.532.582 2.454.582zM105.163 17.143c-1.613 0-3.076-.377-4.389-1.132a8.902 8.902 0 01-3.145-3.12c-.76-1.302-1.14-2.754-1.14-4.354s.38-3.04 1.14-4.32a8.716 8.716 0 013.145-3.051C102.087.389 103.55 0 105.163 0c1.636 0 3.11.377 4.424 1.131a8.36 8.36 0 013.11 3.086c.783 1.28 1.175 2.72 1.175 4.32s-.392 3.052-1.175 4.354a8.623 8.623 0 01-3.11 3.12c-1.314.755-2.788 1.132-4.424 1.132zm0-3.634c.945 0 1.774-.206 2.488-.618a4.366 4.366 0 001.694-1.782c.414-.755.622-1.612.622-2.572s-.208-1.806-.622-2.537a4.506 4.506 0 00-1.694-1.714c-.714-.435-1.543-.652-2.488-.652-.922 0-1.751.217-2.488.652A4.5 4.5 0 00100.981 6c-.392.731-.587 1.577-.587 2.537s.195 1.817.587 2.572a4.686 4.686 0 001.694 1.782c.737.412 1.566.618 2.488.618z"
    />
  </Svg>
);

const InfoIcon = () => (
  <Svg
    width="20"
    height="20"
    viewBox="0 0 24 24"
    stroke="currentColor"
    strokeWidth="2"
    strokeLineCap="round"
    strokeLinejoin="round"
    style={{ flexShrink: 0 }}
  >
    <Circle cx="12" cy="12" r="10"></Circle>
    <Path d="M12 16v-4M12 8h.01"></Path>
  </Svg>
);

const ArrowUpIcon = () => (
  <Svg
    width="20"
    height="20"
    viewBox="0 0 24 24"
    stroke="currentColor"
    strokeWidth="2"
    strokeLineCap="round"
    strokeLinejoin="round"
    style={{ flexShrink: 0 }}
  >
    <Circle cx="12" cy="12" r="10" />
    <Path d="m16 12-4-4-4 4" />
    <Path d="M12 16V8" />
  </Svg>
);

const ArrowDownIcon = () => (
  <Svg
    width="20"
    height="20"
    viewBox="0 0 24 24"
    stroke="currentColor"
    strokeWidth="2"
    strokeLineCap="round"
    strokeLinejoin="round"
    style={{ flexShrink: 0 }}
  >
    <Circle cx="12" cy="12" r="10" />
    <Path d="M12 8v8" />
    <Path d="m8 12 4 4 4-4" />
  </Svg>
);

const TransactionDetailParty = ({ label, style, value }: TransactionDetailPartyProps) => {
  return value ? (
    <View style={{ ...styles.transactionDetailPartyContainer, ...(!!style && { style }) }}>
      <Text
        style={{ ...styles.semanticTypographyBody, color: colors.gray[900], textAlign: 'left' }}
      >
        {label}
      </Text>

      <Text
        style={{ ...styles.semanticTypographyBody, color: colors.gray[600], textAlign: 'right' }}
      >
        {value}
      </Text>
    </View>
  ) : null;
};

const Section = ({ icon, name }: SectionProps) => (
  <View style={styles.containerScreen}>
    <View style={styles.sectionBorder} />
    <View style={styles.sectionContainer}>
      <View style={styles.sectionMarginIcon}>{icon}</View>
      <Text style={{ ...styles.semanticTypographyTitleBig, color: colors.gray[900] }}>{name}</Text>
    </View>
  </View>
);

const Footer = ({
  authenticationData,
  digitableLine,
  isBarcode,
  isPix,
  transactionId,
}: FooterProps) => (
  <View style={styles.footerContainer}>
    {isPix && (
      <>
        {transactionId && (
          <Text style={{ color: colors.gray['900'], ...styles.semanticTypographyTitle }}>
            ID de transação: {transactionId}
          </Text>
        )}
      </>
    )}

    {isBarcode && (
      <>
        {digitableLine && (
          <Text style={{ color: colors.gray['900'], ...styles.semanticTypographyTitle }}>
            Linha digitável: {digitableLine}
          </Text>
        )}

        {authenticationData && (
          <Text style={{ color: colors.gray['900'], ...styles.semanticTypographyTitle }}>
            Código de Autenticação: {authenticationData}
          </Text>
        )}
      </>
    )}

    <Text style={{ color: colors.gray['900'], ...styles.semanticTypographyTitle }}>
      {PAGGO_LEGAL_NAME}
    </Text>
    <Text style={{ color: colors.gray['900'], ...styles.semanticTypographyTitle }}>
      CNPJ: {formatToCPFOrCNPJ(PAGGO_TAX_ID)}
    </Text>
  </View>
);

export const TransactionDetailReceipt = ({ transaction }: TransactionDetailReceiptProps) => {
  const paymentSuccess = useMemo(() => transaction?.status === 'CONFIRMED', [transaction?.status]);

  const isPix = useMemo(
    () => transaction?.method === 'KEY' || transaction?.method === 'QR_CODE',
    [transaction?.method]
  );
  const isBarcode = useMemo(() => transaction?.method === 'BARCODE', [transaction?.method]);

  const title = useMemo(() => {
    if (paymentSuccess) {
      return isPix ? 'Pix enviado' : 'Pagamento efetuado';
    }

    return isPix ? 'Tentativa de pix falhou' : 'Tentativa de pagamento falhou';
  }, [isPix, paymentSuccess]);

  if (!transaction) return <></>;

  return (
    <Document pageMode="fullScreen">
      <Page style={styles.page} size={styles.pageSize}>
        <View style={styles.headerContainer}>
          <View style={styles.logoContainer}>
            <PaggoLogo />
          </View>

          <Text style={{ ...styles.semanticTypographyDisplaySmall, ...styles.marginBottomSmall }}>
            {title}
          </Text>

          <Text style={{ ...styles.semanticTypographyOverheadMid, color: colors.gray[500] }}>
            {toUpper(
              DateTime.fromISO(transaction.date).setLocale('pt-br').toFormat("dd LLL yyyy ' - ' TT")
            ).replace('.', '')}
          </Text>
        </View>

        <View style={styles.transactionDetailPartySection}>
          <TransactionDetailParty
            label="Valor"
            value={formatNumberReal(transaction.amount / 100)}
            style={styles.amountMargin}
          />

          <TransactionDetailParty
            label="Tipo de pagamento"
            value={isPix ? 'Pix' : 'Código de barras'}
            style={styles.paymentTypeMargin}
          />
        </View>

        <View style={styles.transactionDetailPartySectionContainer}>
          <Section name="Dados do Recebedor" icon={<ArrowDownIcon />} />

          <View style={styles.paddingHorizontalMid}>
            <TransactionDetailParty
              label="Nome"
              value={capitalizeString(transaction.creditParty.receiverLegalName)}
            />
            <TransactionDetailParty
              label={cnpjValid(transaction.creditParty?.receiverDocumentNumber) ? 'CNPJ' : 'CPF'}
              value={
                transaction.creditParty?.receiverDocumentNumber &&
                formatToCPFOrCNPJ(transaction.creditParty.receiverDocumentNumber, {
                  mask: 'cpf',
                })
              }
            />
            <TransactionDetailParty
              label="Instituição"
              value={
                transaction.creditParty?.bankCode &&
                capitalizeString(getBankNameFromISPB(transaction.creditParty.bankCode) ?? '')
              }
            />

            {transaction.creditParty?.branch && (
              <TransactionDetailParty
                label="Agência"
                value={
                  transaction.creditParty?.branch && padZero(transaction.creditParty?.branch, 4)
                }
              />
            )}

            <TransactionDetailParty
              label="Conta"
              value={transaction.creditParty?.accountNumber}
              style={styles.marginBottomMid}
            />
          </View>
        </View>

        <View style={styles.transactionDetailPartySectionContainer}>
          <Section name="Dados do Pagador" icon={<ArrowUpIcon />} />

          <View style={styles.paddingHorizontalMid}>
            <TransactionDetailParty
              label="Nome"
              value={capitalizeString(transaction.debitParty.receiverLegalName)}
              style={styles.truncate}
            />

            <TransactionDetailParty
              label={cnpjValid(transaction.debitParty.receiverDocumentNumber) ? 'CNPJ' : 'CPF'}
              value={formatToCPFOrCNPJ(transaction.debitParty.receiverDocumentNumber, {
                mask: 'cpf',
              })}
            />

            <TransactionDetailParty
              label="Instituição"
              value={capitalizeString(getBankNameFromISPB(CELCOIN_BANK.institution) ?? '')}
            />

            <TransactionDetailParty label="Agência" value={padZero(CELCOIN_BANK.branch || '', 4)} />

            <TransactionDetailParty
              label="Conta"
              value={transaction.debitParty.accountNumber}
              style={styles.marginBottomMid}
            />
          </View>
        </View>

        <View style={styles.transactionDetailPartySectionContainer}>
          <Section name="Detalhes da Transação" icon={<InfoIcon />} />

          <View style={styles.paddingHorizontalMid}>
            <TransactionDetailParty
              label="Emissor"
              value={transaction.assignor}
              style={styles.truncate}
            />

            <TransactionDetailParty
              label="Valor original"
              value={formatNumberReal((transaction.amount || 0) / 100)}
            />

            <TransactionDetailParty
              label="Multa"
              value={formatNumberReal((transaction.fineAmount || 0) / 100)}
            />
            <TransactionDetailParty
              label="Juros"
              value={formatNumberReal((transaction.interestAmount || 0) / 100)}
            />
            <TransactionDetailParty
              label="Desconto"
              value={formatNumberReal((transaction.discountAmount || 0) / 100)}
            />
            <TransactionDetailParty
              label="Data de vencimento"
              value={
                transaction?.dueDate &&
                DateTime.fromJSDate(new Date(transaction.dueDate)).toFormat('dd/MM/yyyy')
              }
              style={styles.marginBottomMid}
            />
          </View>
        </View>

        <Footer
          transactionId={transaction.endToEndId}
          isPix={isPix}
          isBarcode={isBarcode}
          digitableLine={transaction.digitableLine}
          authenticationData={transaction.authenticationData}
        />
      </Page>
    </Document>
  );
};
