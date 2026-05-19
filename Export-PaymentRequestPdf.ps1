<#
.SYNOPSIS
    支払申請書（個人及び法人源泉対象取引）の PDF 出力スクリプト

.DESCRIPTION
    MJSFX4Web の WebAPI (FLW300200) を呼び出し、指定された申請書番号の
    支払申請書 PDF をダウンロードしてローカルに保存します。

    本スクリプトは MJS WebAPI の公開仕様が手元にない状態で作成した
    スケルトンです。実際の MJS 環境での仕様 (認証方式・リクエスト
    パラメータ名・レスポンス形式) と差異がある場合は、下記 TODO
    マーカーの付いた箇所を実環境の仕様に合わせて修正してください。

.PARAMETER RequestNo
    PDF 出力対象の申請書番号 (必須)

.PARAMETER BaseUrl
    MJSFX4Web のベース URL。既定値はイントラ環境を想定。

.PARAMETER UserId
    MJS にログインするユーザー ID

.PARAMETER Password
    MJS にログインするパスワード (SecureString)。省略時はプロンプト。

.PARAMETER CompanyCode
    会社コード (MJS では会社切替に必要)

.PARAMETER OutputDir
    PDF の保存先ディレクトリ。既定はカレントディレクトリ。

.EXAMPLE
    .\Export-PaymentRequestPdf.ps1 -RequestNo 202605-0001 -UserId admin -CompanyCode 001
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, Position = 0)]
    [string]$RequestNo,

    [Parameter()]
    [string]$BaseUrl = 'https://ngakukr-0/MJSFX4Web',

    [Parameter(Mandatory = $true)]
    [string]$UserId,

    [Parameter()]
    [SecureString]$Password,

    [Parameter(Mandatory = $true)]
    [string]$CompanyCode,

    [Parameter()]
    [string]$OutputDir = (Get-Location).Path,

    [Parameter()]
    [switch]$SkipCertificateCheck
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if (-not $Password) {
    $Password = Read-Host -AsSecureString -Prompt "Password for $UserId"
}

if ($SkipCertificateCheck) {
    if ($PSVersionTable.PSVersion.Major -ge 6) {
        $script:IwrExtra = @{ SkipCertificateCheck = $true }
    } else {
        Add-Type @"
using System.Net;
using System.Security.Cryptography.X509Certificates;
public class TrustAllCertsPolicy : ICertificatePolicy {
    public bool CheckValidationResult(ServicePoint sp, X509Certificate cert, WebRequest req, int problem) { return true; }
}
"@
        [System.Net.ServicePointManager]::CertificatePolicy = New-Object TrustAllCertsPolicy
        [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12
        $script:IwrExtra = @{}
    }
} else {
    $script:IwrExtra = @{}
}

function ConvertFrom-SecureStringPlain {
    param([SecureString]$Secure)
    $bstr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($Secure)
    try { return [Runtime.InteropServices.Marshal]::PtrToStringBSTR($bstr) }
    finally { [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr) }
}

function Invoke-MjsLogin {
    param(
        [string]$BaseUrl,
        [string]$UserId,
        [SecureString]$Password,
        [string]$CompanyCode
    )

    # TODO: 実環境の MJS WebAPI 認証エンドポイント・パラメータに合わせる
    $loginUrl = "$BaseUrl/WebAPI/Auth/Login"
    $body = @{
        userId      = $UserId
        password    = (ConvertFrom-SecureStringPlain $Password)
        companyCode = $CompanyCode
    } | ConvertTo-Json

    Write-Verbose "POST $loginUrl"
    $session = $null
    $response = Invoke-WebRequest -Uri $loginUrl `
        -Method Post `
        -Body $body `
        -ContentType 'application/json; charset=utf-8' `
        -SessionVariable session `
        @script:IwrExtra

    if ($response.StatusCode -ne 200) {
        throw "Login failed: HTTP $($response.StatusCode)"
    }

    $payload = $response.Content | ConvertFrom-Json
    # TODO: トークン名はサーバ仕様に合わせる (例: token / accessToken / authToken)
    $token = $payload.token
    if (-not $token) {
        throw "Login response did not contain an auth token. Body: $($response.Content)"
    }

    return [pscustomobject]@{
        Session = $session
        Token   = $token
    }
}

function Export-PaymentRequestPdf {
    param(
        [string]$BaseUrl,
        [object]$Auth,
        [string]$RequestNo,
        [string]$OutputPath
    )

    # FLW300200 は支払申請書 (個人及び法人源泉対象取引) のメニュー ID
    # TODO: 実環境では PDF 出力専用のサブパス (例: /Export, /Pdf) が
    # 必要なケースがある。仕様書で確認のうえ書き換えること。
    $exportUrl = "$BaseUrl/WebAPI/Menu/FLW300200/ExportPdf"

    $body = @{
        requestNo  = $RequestNo
        formType   = 'PaymentRequest_WithholdingTax'   # 個人及び法人源泉対象取引
        outputType = 'PDF'
    } | ConvertTo-Json

    $headers = @{
        Authorization = "Bearer $($Auth.Token)"
        Accept        = 'application/pdf'
    }

    Write-Verbose "POST $exportUrl  (requestNo=$RequestNo)"
    Invoke-WebRequest -Uri $exportUrl `
        -Method Post `
        -Body $body `
        -ContentType 'application/json; charset=utf-8' `
        -Headers $headers `
        -WebSession $Auth.Session `
        -OutFile $OutputPath `
        @script:IwrExtra | Out-Null

    if (-not (Test-Path -LiteralPath $OutputPath)) {
        throw "PDF was not written to $OutputPath"
    }

    $fi = Get-Item -LiteralPath $OutputPath
    if ($fi.Length -lt 100) {
        throw "Downloaded file is suspiciously small ($($fi.Length) bytes). Response may be an error page."
    }

    # PDF マジックバイト (%PDF-) の簡易検証
    $head = [System.IO.File]::ReadAllBytes($OutputPath)[0..3]
    $magic = [System.Text.Encoding]::ASCII.GetString($head)
    if ($magic -ne '%PDF') {
        throw "Downloaded file is not a PDF (magic='$magic'). Check API response."
    }
}

# --- main ---
if (-not (Test-Path -LiteralPath $OutputDir)) {
    New-Item -ItemType Directory -Path $OutputDir | Out-Null
}

$safeNo   = ($RequestNo -replace '[^\w\-.]', '_')
$outFile  = Join-Path $OutputDir ("PaymentRequest_{0}_{1:yyyyMMddHHmmss}.pdf" -f $safeNo, (Get-Date))

Write-Host "Logging in to $BaseUrl as $UserId ..."
$auth = Invoke-MjsLogin -BaseUrl $BaseUrl -UserId $UserId -Password $Password -CompanyCode $CompanyCode

Write-Host "Exporting payment request $RequestNo ..."
Export-PaymentRequestPdf -BaseUrl $BaseUrl -Auth $auth -RequestNo $RequestNo -OutputPath $outFile

Write-Host "Saved: $outFile"
