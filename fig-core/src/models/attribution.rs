use serde::{Deserialize, Serialize};
use serde_json::Value;
use std::collections::HashMap;

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize, Default)]
pub struct Attribution {
    #[serde(skip_serializing_if = "Option::is_none")]
    pub commits: Option<bool>,
    #[serde(skip_serializing_if = "Option::is_none")]
    #[serde(rename = "pullRequests")]
    pub pull_requests: Option<bool>,
    #[serde(flatten)]
    pub additional_properties: HashMap<String, Value>,
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_attribution_round_trip() {
        let json = r#"{"commits":true,"pullRequests":false,"unknownField":123}"#;
        let parsed: Attribution = serde_json::from_str(json).unwrap();
        assert_eq!(parsed.commits, Some(true));
        assert_eq!(parsed.pull_requests, Some(false));
        assert_eq!(
            parsed.additional_properties.get("unknownField"),
            Some(&serde_json::json!(123))
        );

        let re_serialized = serde_json::to_string(&parsed).unwrap();
        let re_parsed: Attribution = serde_json::from_str(&re_serialized).unwrap();
        assert_eq!(parsed, re_parsed);
    }

    #[test]
    fn test_attribution_empty() {
        let parsed: Attribution = serde_json::from_str("{}").unwrap();
        assert_eq!(parsed, Attribution::default());
    }

    #[test]
    fn test_attribution_camel_case_rename() {
        let a = Attribution {
            commits: Some(true),
            pull_requests: Some(false),
            ..Default::default()
        };
        let json = serde_json::to_string(&a).unwrap();
        assert!(json.contains("pullRequests"));
        assert!(!json.contains("pull_requests"));
    }
}
