﻿$currentScriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path
$sut = (Split-Path -Leaf $MyInvocation.MyCommand.Path).Replace(".Tests.", ".")
$VerbosePreference = 'Continue'

$invokeRemoteDeployment = "$currentScriptPath\..\..\..\src\Tasks\IISWebAppDeploy\$sut"

if(-not (Test-Path -Path $invokeRemoteDeployment ))
{
    throw [System.IO.FileNotFoundException] "Unable to find InvokeRemoteDeployment.ps1 at $invokeRemoteDeployment"
}

. "$invokeRemoteDeployment"

$InitializationScript = {}

Describe "Tests for testing Invoke-RemoteDeployment functionality" {
    
    $machinesList = "machine1:3234,machine2:2342,machine3:4343"
    $scriptToRun = "dummy Script"
    $adminUserName = "dummyuser"
    $adminPassword = "dummypassword"
    $httpsProtocol = "http"
    $httpsProtocol = "https"
    $doSkipCA = "true"
    $donotSkipCA = "false"
    $cmdToRunScriptBlock = [scriptblock]::Create($scriptToRun)

    
    Mock Get-Credentials -Verifiable { return } -ParameterFilter { $UserName -eq $adminUserName -and $Password -eq $adminPassword }
    Mock Get-MachinePortDict -Verifiable { return @{"machine1"="3234";"machine2"="2342";"machine3"="4343"} } -ParameterFilter { $MachinesList -eq $machinesList -and $Protocol -eq $httpsProtocol}
    Mock Start-Sleep -Verifiable { return } -ParameterFilter { $Seconds -eq 10}
    Mock Write-Host { } -Verifiable

    Context "When run deployment parallel is true and all jobs are successful" {

        $InvokePsOnRemoteScriptBlock = {
            param (
                [string]$machineName,
                [string]$scriptToRun,
                [string]$winRmPort,
                [object]$credential,
                [string]$protocolOption,
                [string]$skipCAOption
            )
            Start-Sleep -Milliseconds 500
            $deploymentResponse = New-Object psobject
            $deploymentResponse | Add-Member -MemberType NoteProperty -Name "Status" -Value "Passed"
            Write-Output $deploymentResponse
        }

        $errMsg = Invoke-RemoteDeployment -machinesList $machinesList -scriptToRun $scriptToRun -adminUserName $adminUserName -adminPassword $adminPassword -protocol $httpsProtocol -testCertificate $doSkipCA -deployInParallel "true" 

        It "Should process jobs in parallel and wait for their completion"{
            Assert-VerifiableMocks
            ($errMsg) | Should Be ""
            Assert-MockCalled Write-Host -Times 6 -Exactly
        }
    }

    Context "When run deployment in parallel is true and one job fails" {
        $InvokePsOnRemoteScriptBlock = {
            param (
                [string]$machineName,
                [string]$scriptToRun,
                [string]$winRmPort,
                [object]$credential,
                [string]$protocolOption,
                [string]$skipCAOption
            )
            Start-Sleep -Milliseconds 500

            $deploymentResponse = New-Object psobject
            $status = "Passed"
            if($machineName -eq "machine2")
            {
                $errObj = New-Object psobject
                $errObj | Add-Member -MemberType NoteProperty -Name "Message" -Value "Deployment failed."
                $status = "Failed"
                $deploymentResponse | Add-Member -MemberType NoteProperty -Name "Error" -Value $errObj
            }
            $deploymentResponse | Add-Member -MemberType NoteProperty -Name "Status" -Value $status
            Write-Output $deploymentResponse
        }
        
        $errMsg = Invoke-RemoteDeployment -machinesList $machinesList -scriptToRun $scriptToRun -adminUserName $adminUserName -adminPassword $adminPassword -protocol $httpsProtocol -testCertificate $doSkipCA -deployInParallel "true" 

        It "Should process jobs in parallel and wait for their completion"{
            Assert-VerifiableMocks
            ($errMsg) | Should Be "Deployment on one or more machines failed."
            Assert-MockCalled Write-Host -Times 7 -Exactly
        }
    }

    Context "When run deployment in parallel is false and one job fails" {

        $InvokePsOnRemoteScriptBlock = {
            param (
                [string]$machineName,
                [string]$scriptToRun,
                [string]$winRmPort,
                [object]$credential,
                [string]$protocolOption,
                [string]$skipCAOption
            )
            Start-Sleep -Milliseconds 500

            $deploymentResponse = New-Object psobject
            $status = "Passed"
            if($machineName -eq "machine3")
            {
                $errObj = New-Object psobject
                $errObj | Add-Member -MemberType NoteProperty -Name "Message" -Value "Deployment failed."
                $status = "Failed"
                $deploymentResponse | Add-Member -MemberType NoteProperty -Name "Error" -Value $errObj
            }
            $deploymentResponse | Add-Member -MemberType NoteProperty -Name "Status" -Value $status
            Write-Output $deploymentResponse
        }

        $errMsg = Invoke-RemoteDeployment -machinesList $machinesList -scriptToRun $scriptToRun -adminUserName $adminUserName -adminPassword $adminPassword -protocol $httpsProtocol -testCertificate $doSkipCA -deployInParallel "false" 

        It "Should stop execution after failing for one machine"{
            Assert-VerifiableMocks
            ($errMsg) | Should Be "Deployment on one or more machines failed."
            Assert-MockCalled Write-Host -Times 4 -Exactly
        }
    }

    Context "When run deployment in parallel is false and all jobs are successful" {

        $InvokePsOnRemoteScriptBlock = {
            param (
                [string]$machineName,
                [string]$scriptToRun,
                [string]$winRmPort,
                [object]$credential,
                [string]$protocolOption,
                [string]$skipCAOption
            )
            Start-Sleep -Milliseconds 500
            $deploymentResponse = New-Object psobject
            $deploymentResponse | Add-Member -MemberType NoteProperty -Name "Status" -Value "Passed"
            Write-Output $deploymentResponse
        }

        $errMsg = Invoke-RemoteDeployment -machinesList $machinesList -scriptToRun $scriptToRun -adminUserName $adminUserName -adminPassword $adminPassword -protocol $httpsProtocol -testCertificate $doSkipCA -deployInParallel "false" 

        It "Should complete all the machines deployment sequentially"{
            Assert-VerifiableMocks
            ($errMsg) | Should Be ""
            Assert-MockCalled Write-Host -Times 6 -Exactly
        }
    }
}

Describe "Test for testing functionality of Get-SkipCAOption" {

    Context "When testCertificate is true" {

        $skipCAOption = Get-SkipCAOption -useTestCertificate "true"

        It "Should return -SkipCACheck for skipCAOption" {
            ($skipCAOption ) | Should Be "-SkipCACheck"
        }
    }

    Context "When testCertificate is false" {

        $skipCAOption = Get-SkipCAOption -useTestCertificate "false"

        It "Should return empty for skipCAOption" {
            ($skipCAOption ) | Should Be ""
        }
    }

}

Describe "Tests for testing Get-ProtocolOption functionality" {

    Context "When protocol input is http" {

        $protocolOption = Get-ProtocolOption -protocol "http"

        It "Should return -UseHttp for protocolOption" {
            ($protocolOption ) | Should Be "-UseHttp"
        }

    }

    Context "When protocol input is https" {

        $protocolOption = Get-ProtocolOption -protocol "https"

        It "Should return empty for protocolOption" {
            ($protocolOption ) | Should Be ""
        }
    }
}

Describe "Tests for testing Get-Credentials function" {

    Context "When user name or password is empty" {
        $errorMsg = "Invalid administrator credentials."
        It "Should throw exception" {
            { Get-Credentials -userName "" -password "not empty"} | Should Throw $errorMsg
            { Get-Credentials -userName "not empty" -password ""} | Should Throw $errorMsg
        }
    }

    Context "When both the inputs are valid" {
        $creds = Get-Credentials -userName "user" -password "password"
        
        It "Should return credentials object" {
            ($creds.ToString()) | Should Be "System.Management.Automation.PSCredential"
            ($creds.UserName) | Should Be "user"
        }
    }
}

Describe "Tests for testing Get-MachinePortDict function" {

    Context "When machinesList is machine1 and protocol http" {

        $machines = Get-MachinePortDict -machinesList "machine1" -protocol "http"

        It "Should create dict with @{`"machine1`":`"5985`"}" {
            ($machines.Count) | Should Be 1
            ($machines.Keys[0]) | Should Be "machine1"
            ($machines["machine1"]) | Should Be "5985"
        }
    }
    
    Context "When machinesList is machine1 and protocol https" {

        $machines = Get-MachinePortDict -machinesList "machine1" -protocol "https"

        It "Should create dict with @{`"machine1`":`"5986`"}" {
            ($machines.Count) | Should Be 1
            ($machines.Keys[0]) | Should Be "machine1"
            ($machines["machine1"]) | Should Be "5986"
        }
    }
    
    Context "When machinesList is machine1:8345 with http" {

        $machines = Get-MachinePortDict -machinesList "machine1:8345" -protocol "http"

        It "Should create dict with @{`"machine1`":`"8345`"}" {
            ($machines.Count) | Should Be 1
            ($machines.Keys[0]) | Should Be "machine1"
            ($machines["machine1"]) | Should Be "8345"
        }
    }
    
    Context "When machinesList is machine1:2332,machine2:4343 with https" {

        $machines = Get-MachinePortDict -machinesList "machine1:2332,machine2:4343" -protocol "https"

        It "Should create dict with @{`"machine1`":`"2332`";`"machine2`":`"4343`";}" {
            ($machines.Count) | Should Be 2
            ($machines["machine1"]) | Should Be "2332"
            ($machines["machine2"]) | Should Be "4343"
        }
    }
    
    Context "When machineLust is machine1:4344,machine2,machine3:4389 with https" {

        $machines = Get-MachinePortDict -machinesList "machine1:4344,machine2,machine3:4389" -protocol "https"

        It "Should create dict with @{`"machine1`":`"4344`";`"machine2`":`"5986`";`"machine3`":`"4389`"}" {
            ($machines.Count) | Should Be 3
            ($machines["machine1"]) | Should Be "4344"
            ($machines["machine2"]) | Should Be "5986"
            ($machines["machine3"]) | Should Be "4389"
        }
    }

    Context "When machineLust is machine1:4344,machine2,machine3:4389 with http" {

        $machines = Get-MachinePortDict -machinesList "machine1:4344,machine2,machine3:4389" -protocol "http"

        It "Should create dict with @{`"machine1`":`"4344`";`"machine2`":`"5986`";`"machine3`":`"4389`"}" {
            ($machines.Count) | Should Be 3
            ($machines["machine1"]) | Should Be "4344"
            ($machines["machine2"]) | Should Be "5985"
            ($machines["machine3"]) | Should Be "4389"
        }
    }
    
    
    Context "When machines list contains spaces or newlines machine1, ,machine2,\n,machine3" {

        $machines = Get-MachinePortDict -machinesList "machine1, ,machine2,\n,machine3" -protocol "http"

        It "Should create dict with @{`"machine1`":`"5985`";`"machine2`":`"5985`";`"machine3`":`"595`"}" {
            ($machines.Count) | Should Be 3
            ($machines["machine1"]) | Should Be "5985"
            ($machines["machine2"]) | Should Be "5985"
            ($machines["machine3"]) | Should Be "5985"
        }
    }
}

Describe "Tests for testing Get-MachineNameAndPort functionality" {
    Context "When machine name or port has leading or trailing white spaces ex: machine1 : 5343" {

        $tokens = Get-MachineNameAndPort -machine "machine1 : 5343"

        It "Should return array with @(machine1,5343)" {
            ($tokens.Count) | Should Be 2
            ($tokens[0]) | Should Be "machine1"
            ($tokens[1]) | Should Be "5343"
        }
    }

    Context "When machine name is empty :5986 with https" {

        $errorMsg = "Invalid user input, machine name can not be empty."

        It "Should throw exception" {
            { Get-MachineNameAndPort -machine ":5986" } | Should Throw $errorMsg
        }
    }

    Context "When port is not a valid integer machine1:port1" {

        $errorMsg = "Invalid user input, port is not an integer."

        It "Should throw exception" {
            { Get-MachineNameAndPort -machine "machine1:port" } | Should Throw $errorMsg
        }
    }

    Context "When machine port combination has more than two tokens machine1:port1:port2" {

        $errorMsg = "Invalid user input, speficy machines in machine:port format."

        It "Should throw exception" {
            { Get-MachineNameAndPort -machine "machine1:port1:port2" } | Should Throw $errorMsg
        }
    }
}