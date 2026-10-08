<#
.SYNOPSIS
    Intune Enterprise Fleet Triage & Sync Engine

.DESCRIPTION
    An enterprise-grade modern endpoint diagnostics and synchronization framework designed to bridge the gap between OMA-DM and IME execution states.

.NOTES
    Author:      Souhaiel Morhag
    Company:     MSEndpoint.com
    Blog:        https://msendpoint.com
    Academy:     https://app.msendpoint.com/academy
    LinkedIn:    https://linkedin.com/in/souhaiel-morhag
    GitHub:      https://github.com/Msendpoint
    Created:     2026-10-08
    License:     MIT

.EXAMPLE
    .\script.ps1
#>

### FILE: index.php
<?php
/**
 * Intune Enterprise Fleet Triage Dashboard
 * 
 * Translates modern endpoint telemetry and dual-channel agent state analysis
 * from raw Graph API transactions into a high-fidelity administrative dashboard.
 */

$accessToken = $_SESSION['ms_access_token'] ?? null;
if (!$accessToken) {
    echo "<div class='alert alert-danger'>Authentication Context Lost. Please log in to Microsoft 365.</div>";
    return;
}

// Configuration parameters matching architectural defaults
$deviceNameFilter = "CON-WIN11";
$syncAgeHoursThreshold = 24;
$cutoffTime = time() - ($syncAgeHoursThreshold * 3600);

// 1. Fetch Managed Devices via Graph Substrate
$selectFields = "id,deviceName,userPrincipalName,lastSyncDateTime,complianceState,operatingSystem,osVersion";
$devicesEndpoint = "deviceManagement/managedDevices?\$filter=startsWith(deviceName,'{$deviceNameFilter}')&\$select={$selectFields}";

try {
    $devicesResult = $ms->graphCall($devicesEndpoint, $accessToken, 'GET');
    $devices = $devicesResult['value'] ?? [];
} catch (Exception $e) {
    echo "<div class='alert alert-danger'>Graph API Error: " . htmlspecialchars($e->getMessage()) . "</div>";
    return;
}

$totalDevices = count($devices);
$staleCount = 0;
$failedAppsTotalCount = 0;
$triageReport = [];

foreach ($devices as $device) {
    $deviceId = $device['id'];
    $deviceName = $device['deviceName'];
    $upn = $device['userPrincipalName'];
    $compliance = $device['complianceState'];
    $lastSyncStr = $device['lastSyncDateTime'];
    
    $lastSyncTime = strtotime($lastSyncStr);
    $isStale = $lastSyncTime < $cutoffTime;
    if ($isStale) {
        $staleCount++;
    }

    $failedApps = [];
    // 2. Probe Win32 App Enrollment Engine Failures for lagging or non-compliant machines
    if ($isStale || $compliance !== 'compliant') {
        $appStatusEndpoint = "deviceManagement/managedDevices('{$deviceId}')/deviceInstallStates?\$filter=installState eq 'failed'";
        try {
            $appResponse = $ms->graphCall($appStatusEndpoint, $accessToken, 'GET');
            $appStates = $appResponse['value'] ?? [];
            foreach ($appStates as $state) {
                $failedApps[] = $state['appName'] . " [Code: " . ($state['errorCode'] ?? 'Unknown') . "]";
                $failedAppsTotalCount++;
            }
        } catch (Exception $e) {
            // Gracefully catch secondary queries to prevent dashboard halt
            $failedApps[] = "Query Failed: " . $e->getMessage();
        }
    }

    $triageReport[] = [
        'id' => $deviceId,
        'name' => $deviceName,
        'upn' => $upn,
        'compliance' => $compliance,
        'lastSync' => $lastSyncStr,
        'stale' => $isStale,
        'failedApps' => $failedApps
    ];
}

$stalePercentage = $totalDevices > 0 ? round(($staleCount / $totalDevices) * 100) : 0;
?>

<div class="container-fluid py-4">
    <div class="row mb-4">
        <div class="col-md-4">
            <?php echo render_premium_card("Total Monitored Fleet", $totalDevices, "Filter: {$deviceNameFilter}*", "up", "💻"); ?>
        </div>
        <div class="col-md-4">
            <?php echo render_premium_card("Stale Endpoints (>24h)", $staleCount, "{$stalePercentage}% of monitored fleet", $staleCount > 0 ? 'down' : 'up', "⏰", $stalePercentage); ?>
        </div>
        <div class="col-md-4">
            <?php echo render_premium_card("Critical App Failures", $failedAppsTotalCount, "Requires immediate remediation", $failedAppsTotalCount > 0 ? 'down' : 'up', "⚠️"); ?>
        </div>
    </div>

    <div class="card shadow-sm border-0">
        <div class="card-header bg-dark text-white d-flex justify-content-between align-items-center">
            <h5 class="mb-0"><i class="bi bi-cpu-fill me-2"></i>Dual-Channel Endpoint Diagnostic Triage</h5>
            <span class="badge bg-secondary">Real-time Telemetry</span>
        </div>
        <div class="card-body bg-light">
            <div class="table-responsive">
                <table class="table table-hover align-middle bg-white rounded shadow-sm">
                    <thead class="table-light">
                        <tr>
                            <th>Device Name</th>
                            <th>Primary User (UPN)</th>
                            <th>Compliance State</th>
                            <th>Last Sync Timestamp</th>
                            <th>IME App Status</th>
                            <th class="text-end">Actions</th>
                        </tr>
                    </thead>
                    <tbody>
                        <?php if (empty($triageReport)): ?>
                            <tr>
                                <td colspan="6" class="text-center py-4 text-muted">No devices found matching current filters.</td>
                            </tr>
                        <?php else: ?>
                            <?php foreach ($triageReport as $row): ?>
                                <tr class="<?php echo $row['stale'] ? 'table-warning' : ''; ?>">
                                    <td><strong><?php echo htmlspecialchars($row['name']); ?></strong></td>
                                    <td><small class="text-muted"><?php echo htmlspecialchars($row['upn']); ?></small></td>
                                    <td>
                                        <span class="badge bg-<?php echo $row['compliance'] === 'compliant' ? 'success' : 'danger'; ?>">
                                            <?php echo htmlspecialchars($row['compliance']); ?>
                                        </span>
                                    </td>
                                    <td>
                                        <span class="<?php echo $row['stale'] ? 'text-danger fw-bold' : 'text-success'; ?>">
                                            <?php echo date('Y-m-d H:i:s', strtotime($row['lastSync'])); ?></span>
                                    </td>
                                    <td>
                                        <?php if (empty($row['failedApps'])): ?>
                                            <span class="badge bg-success">No Failures</span>
                                        <?php else: ?>
                                            <?php foreach ($row['failedApps'] as $failedApp): ?>
                                                <span class="badge bg-danger d-block mb-1 text-wrap text-start">
                                                    <?php echo htmlspecialchars($failedApp); ?>
                                                </span>
                                            <?php endforeach; ?>
                                        <?php endif; ?>
                                    </td>
                                    <td class="text-end">
                                        <?php if ($row['stale']): ?>
                                            <form method="POST" action="trigger
Wait, let's make sure the end of the script block is fully generated and completed.
    `successfully.\" -InformationAction Continue\n    exit 0\n}"`

    Let's check the JSON structure:
    ```json
    ...
    ]
    }