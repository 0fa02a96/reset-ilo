# Ruta del archivo con el listado de equipos
$equiposFilePath = "C:\ruta\del\archivo\equipos.txt"

# Verificar si el archivo existe
if (-not (Test-Path -Path $equiposFilePath)) {
    Write-Output "El archivo con el listado de equipos no se encontró en la ruta especificada."
    exit
}

# Forzar el uso de TLS 1.2
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# Pedir la contraseña una vez
$usuario = "pepito"
$contraseña = Read-Host -AsSecureString "Ingrese la contraseña de iLO"

# Convertir la contraseña a texto plano (solo para el propósito de autenticación con RESTful)
$plainPassword = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($contraseña))

# Ignorar advertencias de certificado SSL
Add-Type @"
    using System.Net;
    using System.Security.Cryptography.X509Certificates;
    public class SSLHandler {
        public static bool IgnoreCertificateErrors() {
            ServicePointManager.ServerCertificateValidationCallback = delegate { return true; };
            return true;
        }
    }
"@
[void][SSLHandler]::IgnoreCertificateErrors()

# Leer el archivo de equipos
$equipos = Get-Content -Path $equiposFilePath

# Iterar sobre cada equipo en el archivo
foreach ($equipo in $equipos) {
    Write-Output "Reiniciando iLO en el equipo: $equipo"

    try {
        # Enviar solicitud RESTful para reiniciar iLO
        $url = "https://$equipo/redfish/v1/Managers/1/Actions/Manager.Reset"
        $headers = @{
            Authorization = "Basic " + [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes("${usuario}:${plainPassword}"))
        }
        $body = @{
            Action = "Reset"
            ResetType = "ForceRestart"
        } | ConvertTo-Json

        # Enviar la solicitud POST para reiniciar
        $response = Invoke-RestMethod -Uri $url -Method Post -Headers $headers -Body $body -ContentType "application/json"
        Write-Output "Reinicio de iLO iniciado en: $equipo"
    } catch {
        Write-Output "Error al reiniciar iLO en el equipo: $equipo"
        Write-Output $_.Exception.Message
    }
}

# Limpiar la contraseña de memoria
[System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR([Runtime.InteropServices.Marshal]::SecureStringToBSTR($contraseña))

Write-Output "Proceso de reinicio completado para todos los equipos en el archivo."
