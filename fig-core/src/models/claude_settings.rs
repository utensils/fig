use serde::{Deserialize, Serialize};
use serde_json::Value;
use std::collections::HashMap;

use super::attribution::Attribution;
use super::hook_group::HookGroup;
use super::permissions::Permissions;

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize, Default)]
pub struct ClaudeSettings {
    #[serde(skip_serializing_if = "Option::is_none")]
    pub permissions: Option<Permissions>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub env: Option<HashMap<String, String>>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub hooks: Option<HashMap<String, Vec<HookGroup>>>,
    #[serde(skip_serializing_if = "Option::is_none")]
    #[serde(rename = "disallowedTools")]
    pub disallowed_tools: Option<Vec<String>>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub attribution: Option<Attribution>,
    #[serde(flatten)]
    pub additional_properties: HashMap<String, Value>,
}

impl ClaudeSettings {
    pub fn hooks_for(&self, event: &str) -> Option<&Vec<HookGroup>> {
        self.hooks.as_ref()?.get(event)
    }

    pub fn hook_event_names(&self) -> Vec<String> {
        self.hooks
            .as_ref()
            .map(|h| h.keys().cloned().collect())
            .unwrap_or_default()
    }

    pub fn is_tool_disallowed(&self, tool_name: &str) -> bool {
        self.disallowed_tools
            .as_ref()
            .map(|tools| tools.contains(&tool_name.to_string()))
            .unwrap_or(false)
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    const CLAUDE_SETTINGS_JSON: &str = r#"{"permissions":{"allow":["Bash(npm run *)"],"deny":["Read(.env)"]},"env":{"CLAUDE_CODE_MAX_OUTPUT_TOKENS":"16384"},"hooks":{"PreToolUse":[{"matcher":"Bash(*)","hooks":[{"type":"command","command":"echo pre"}]}]},"disallowedTools":["DangerousTool"],"attribution":{"commits":true,"pullRequests":true},"experimentalFeature":"enabled"}"#;

    #[test]
    fn test_claude_settings_full_round_trip() {
        let parsed: ClaudeSettings = serde_json::from_str(CLAUDE_SETTINGS_JSON).unwrap();
        assert_eq!(
            parsed.permissions.as_ref().unwrap().allow,
            Some(vec!["Bash(npm run *)".to_string()])
        );
        assert_eq!(
            parsed
                .env
                .as_ref()
                .unwrap()
                .get("CLAUDE_CODE_MAX_OUTPUT_TOKENS"),
            Some(&"16384".to_string())
        );
        assert_eq!(
            parsed.disallowed_tools,
            Some(vec!["DangerousTool".to_string()])
        );
        assert_eq!(parsed.attribution.as_ref().unwrap().commits, Some(true));
        assert_eq!(
            parsed.additional_properties.get("experimentalFeature"),
            Some(&Value::String("enabled".to_string()))
        );

        let re_serialized = serde_json::to_string(&parsed).unwrap();
        let re_parsed: ClaudeSettings = serde_json::from_str(&re_serialized).unwrap();
        assert_eq!(parsed, re_parsed);
    }

    #[test]
    fn test_claude_settings_minimal() {
        let parsed: ClaudeSettings = serde_json::from_str("{}").unwrap();
        assert_eq!(parsed, ClaudeSettings::default());
    }

    #[test]
    fn test_claude_settings_hooks_lookup() {
        let parsed: ClaudeSettings = serde_json::from_str(CLAUDE_SETTINGS_JSON).unwrap();
        assert!(parsed.hooks_for("PreToolUse").is_some());
        assert_eq!(parsed.hooks_for("PreToolUse").unwrap().len(), 1);
        assert!(parsed.hooks_for("NonExistent").is_none());
    }

    #[test]
    fn test_claude_settings_disallowed_tool_check() {
        let parsed: ClaudeSettings = serde_json::from_str(CLAUDE_SETTINGS_JSON).unwrap();
        assert!(parsed.is_tool_disallowed("DangerousTool"));
        assert!(!parsed.is_tool_disallowed("SafeTool"));
    }

    #[test]
    fn test_claude_settings_hook_event_names() {
        let parsed: ClaudeSettings = serde_json::from_str(CLAUDE_SETTINGS_JSON).unwrap();
        let names = parsed.hook_event_names();
        assert!(names.contains(&"PreToolUse".to_string()));
    }
}
