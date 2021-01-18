$MyInvocation.MyCommand.Path | Split-Path | Push-Location;

# Update the path if you install a different  version of AI NuGet package
Add-Type -Path .\Dependencies\Microsoft.ApplicationInsights.2.16.0\lib\netstandard2.0\Microsoft.ApplicationInsights.dll;

$InstrumentationKey = $Env:APPINSIGHTS_INSTRUMENTATIONKEY;
# If your resource is in a region like Azure Government or Azure China, change the endpoint address accordingly.
# Visit https://docs.microsoft.com/azure/azure-monitor/app/custom-endpoints#regions-that-require-endpoint-modification
$EndpointAddress = "https://dc.services.visualstudio.com/v2/track";

$Channel = [Microsoft.ApplicationInsights.Channel.InMemoryChannel]::new();
$Channel.EndpointAddress = $EndpointAddress;
$TelemetryConfiguration = [Microsoft.ApplicationInsights.Extensibility.TelemetryConfiguration]::new(
    $InstrumentationKey,  
    $Channel
);
$TelemetryClient = [Microsoft.ApplicationInsights.TelemetryClient]::new($TelemetryConfiguration);
$TestName = "AvailabilityTestFunction";
$TestLocation = $Env:COMPUTERNAME; # you can use any string for this

$OperationId = (New-Guid).ToString("N");
$Availability = [Microsoft.ApplicationInsights.DataContracts.AvailabilityTelemetry]::new();
$Availability.Id = $OperationId;
$Availability.Name = $TestName;
$Availability.RunLocation = $TestLocation;
$Availability.Success = $False;

$Stopwatch =  [System.Diagnostics.Stopwatch]::New()
$stopwatch.Start();

$OriginalErrorActionPreference = $ErrorActionPreference;
Try
{
    $ErrorActionPreference = "Stop";
    # Run test
    $Response = Invoke-WebRequest -Uri "https://swimburger.net";
    $Success = $Response.StatusCode -eq 200;
    # End test
    $Availability.Success = $Success;
}
Catch
{
    $Availability.Message = $_.Exception.Message;
    $ExceptionTelemetry = [Microsoft.ApplicationInsights.DataContracts.ExceptionTelemetry]::new($_.Exception);
    $ExceptionTelemetry.Context.Operation.Id = $OperationId;
    $ExceptionTelemetry.Properties.Add("TestName", $TestName);
    $ExceptionTelemetry.Properties.Add("TestLocation", $TestLocation);
    $TelemetryClient.TrackException($ExceptionTelemetry);
}
Finally
{
    $Stopwatch.Stop();
    $Availability.Duration = $Stopwatch.Elapsed;
    $Availability.Timestamp = [DateTimeOffset]::UtcNow;
    
    $TelemetryClient.TrackAvailability($Availability);
    # call flush to ensure telemetry is sent
    $TelemetryClient.Flush();
    $ErrorActionPreference = $OriginalErrorActionPreference;
}

Pop-Location;