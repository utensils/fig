use serde::{Deserialize, Serialize};
use serde_json::Value;
use std::collections::HashMap;

use super::hook_definition::HookDefinition;

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize, Default)]
pub struct HookGroup {
    #[serde(skip_serializing_if = "Option::is_none")]
    pub matcher: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub hooks: Option<Vec<HookDefinition>>,
    #[serde(flatten)]
    pub additional_properties: HashMap<String, Value>,
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_hook_group_round_trip() {
        let json = r#"{"matcher":"Bash(*)","hooks":[{"type":"command","command":"npm run lint"}],"priority":1}"#;
        let parsed: HookGroup = serde_json::from_str(json).unwrap();
        assert_eq!(parsed.matcher, Some("Bash(*)".to_string()));
        assert_eq!(parsed.hooks.as_ref().unwrap().len(), 1);
        assert_eq!(
            parsed.additional_properties.get("priority"),
            Some(&serde_json::json!(1))
        );

        let re_serialized = serde_json::to_string(&parsed).unwrap();
        let re_parsed: HookGroup = serde_json::from_str(&re_serialized).unwrap();
        assert_eq!(parsed, re_parsed);
    }

    #[test]
    fn test_hook_group_empty() {
        let parsed: HookGroup = serde_json::from_str("{}").unwrap();
        assert_eq!(parsed, HookGroup::default());
    }
}
