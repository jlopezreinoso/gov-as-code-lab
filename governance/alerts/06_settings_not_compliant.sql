-- Settings del workspace distintos a los esperados (GOV-HRD-002).
SELECT setting_key, expected_value, actual_value, last_checked
FROM ${gov_catalog}.platform.platform_settings_baseline
WHERE compliant = false
