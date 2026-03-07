use serde::{Deserialize, Serialize};
use serde_json::Value;
use std::collections::HashMap;

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize, Default)]
pub struct Permissions {
    #[serde(skip_serializing_if = "Option::is_none")]
    pub allow: Option<Vec<String>>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub deny: Option<Vec<String>>,
    #[serde(flatten)]
    pub additional_properties: HashMap<String, Value>,
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_permissions_round_trip() {
        let json = r#"{"allow":["Bash(npm run *)","Read(src/**)"],"deny":["Read(.env)","Bash(curl *)"],"futureField":"preserved"}"#;
        let parsed: Permissions = serde_json::from_str(json).unwrap();
        assert_eq!(
            parsed.allow,
            Some(vec![
                "Bash(npm run *)".to_string(),
                "Read(src/**)".to_string()
            ])
        );
        assert_eq!(
            parsed.deny,
            Some(vec!["Read(.env)".to_string(), "Bash(curl *)".to_string()])
        );
        assert_eq!(
            parsed.additional_properties.get("futureField"),
            Some(&Value::String("preserved".to_string()))
        );

        let re_serialized = serde_json::to_string(&parsed).unwrap();
        let re_parsed: Permissions = serde_json::from_str(&re_serialized).unwrap();
        assert_eq!(parsed, re_parsed);
    }

    #[test]
    fn test_permissions_empty() {
        let parsed: Permissions = serde_json::from_str("{}").unwrap();
        assert_eq!(parsed, Permissions::default());
    }

    #[test]
    fn test_permissions_skip_none_fields() {
        let p = Permissions::default();
        let json = serde_json::to_string(&p).unwrap();
        assert_eq!(json, "{}");
    }
}
