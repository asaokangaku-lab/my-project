# my-project

MJSFX4Web 上の支払申請書（個人及び法人源泉対象取引）を PDF として
出力するための PowerShell スクリプトを提供します。

## 必要環境

- Windows PowerShell 5.1 もしくは PowerShell 7+
- MJSFX4Web (FLW300200) にアクセスできるネットワーク
- MJS のログイン情報（ユーザー ID / パスワード / 会社コード）

## 使い方

```powershell
.\Export-PaymentRequestPdf.ps1 `
    -RequestNo 202605-0001 `
    -UserId    admin `
    -CompanyCode 001
```

パスワードは省略するとプロンプトで安全に入力できます。社内環境で
自己署名証明書が使われている場合は `-SkipCertificateCheck` を付けて
ください。

```powershell
.\Export-PaymentRequestPdf.ps1 -RequestNo 202605-0001 `
    -UserId admin -CompanyCode 001 `
    -BaseUrl 'https://ngakukr-0/MJSFX4Web' `
    -OutputDir 'C:\temp\pdf' `
    -SkipCertificateCheck
```

## 注意

スクリプト内のログイン / PDF 出力エンドポイントは MJS WebAPI の
一般的なパターンを推測した実装です。実環境の API 仕様書に従って
`Invoke-MjsLogin` および `Export-PaymentRequestPdf` の URL・パラメータ
名・認証ヘッダを調整してください（コード内の `TODO` コメント参照）。
