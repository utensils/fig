use serde::{Deserialize, Serialize};
use serde_json::Value;
use std::collections::HashMap;

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize, Default)]
pub struct HookDefinition {
    #[serde(skip_serializing_if = "Option::is_none")]
    #[serde(rename = "type")]
    pub hook_type: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub command: Option<String>,
    #[serde(flatten)]
    pub additional_properties: HashMap<String, Value>,
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_hook_definition_round_trip() {
        let json = r#"{"type":"command","command":"npm run lint","timeout":30}"#;
        let parsed: HookDefinition = serde_json::from_str(json).unwrap();
        assert_eq!(parsed.hook_type, Some("command".to_string()));
        assert_eq!(parsed.command, Some("npm run lint".to_string()));
        assert_eq!(
            parsed.additional_properties.get("timeout"),
            Some(&serde_json::json!(30))
        );

        let re_serialized = serde_json::to_string(&parsed).unwrap();
        let re_parsed: HookDefinition = serde_json::from_str(&re_serialized).unwrap();
        assert_eq!(parsed, re_parsed);
    }

    #[test]
    fn test_hook_definition_type_rename() {
        let h = HookDefinition {
            hook_type: Some("command".to_string()),
            ..Default::default()
        };
        let json = serde_json::to_string(&h).unwrap();
        assert!(json.contains(r#""type":"command""#));
    }

    #[test]
    fn test_hook_definition_empty() {
        let parsed: HookDefinition = serde_json::from_str("{}").unwrap();
        assert_eq!(parsed, HookDefinition::default());
    }
}
