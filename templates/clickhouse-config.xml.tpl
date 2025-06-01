<?xml version="1.0"?>
<clickhouse>
    <!-- Network access for external connections -->
    <listen_host>0.0.0.0</listen_host>
    
    <!-- Monitoring endpoint -->
    <prometheus>
        <endpoint>/metrics</endpoint>
        <port>9363</port>
        <metrics>true</metrics>
        <events>true</events>
        <asynchronous_metrics>true</asynchronous_metrics>
    </prometheus>
    
    <!-- Backup support -->
    <storage_configuration>
        <disks>
            <backups>
                <type>local</type>
                <path>/opt/clickhouse-backups/</path>
            </backups>
        </disks>
    </storage_configuration>
    
    <!-- Security: Hide passwords in logs -->
    <query_masking_rules>
        <rule>
            <n>hide passwords</n>
            <regexp>PASSWORD\s*\(\s*'([^']*)'</regexp>
            <replace>PASSWORD('***')</replace>
        </rule>
    </query_masking_rules>
</clickhouse>