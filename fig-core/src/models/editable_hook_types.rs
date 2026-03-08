use std::fmt;

use uuid::Uuid;

use super::hook_definition::HookDefinition;
use super::hook_group::HookGroup;

#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash)]
pub enum HookEvent {
    PreToolUse,
    PostToolUse,
    Notification,
    Stop,
}

impl HookEvent {
    pub fn display_name(&self) -> &str {
        match self {
            Self::PreToolUse => "Pre Tool Use",
            Self::PostToolUse => "Post Tool Use",
            Self::Notification => "Notification",
            Self::Stop => "Stop",
        }
    }

    pub fn key(&self) -> &str {
        match self {
            Self::PreToolUse => "PreToolUse",
            Self::PostToolUse => "PostToolUse",
            Self::Notification => "Notification",
            Self::Stop => "Stop",
        }
    }

    pub fn description(&self) -> &str {
        match self {
            Self::PreToolUse => "Runs before a tool is executed. Can block the tool.",
            Self::PostToolUse => "Runs after a tool has been executed.",
            Self::Notification => "Runs when Claude sends a notification.",
            Self::Stop => "Runs when Claude finishes a response.",
        }
    }

    pub fn supports_matcher(&self) -> bool {
        matches!(self, Self::PreToolUse | Self::PostToolUse)
    }

    pub fn all() -> &'static [HookEvent] {
        &[
            Self::PreToolUse,
            Self::PostToolUse,
            Self::Notification,
            Self::Stop,
        ]
    }
}

impl fmt::Display for HookEvent {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        write!(f, "{}", self.display_name())
    }
}

#[derive(Debug, Clone, PartialEq)]
pub struct EditableHookDefinition {
    pub id: Uuid,
    pub hook_type: String,
    pub command: String,
    pub timeout: Option<u64>,
}

impl EditableHookDefinition {
    pub fn new(command: String) -> Self {
        Self {
            id: Uuid::new_v4(),
            hook_type: "command".to_string(),
            command,
            timeout: None,
        }
    }

    pub fn from_definition(def: &HookDefinition) -> Self {
        let timeout = def
            .additional_properties
            .get("timeout")
            .and_then(|v| v.as_u64());
        Self {
            id: Uuid::new_v4(),
            hook_type: def
                .hook_type
                .clone()
                .unwrap_or_else(|| "command".to_string()),
            command: def.command.clone().unwrap_or_default(),
            timeout,
        }
    }

    pub fn to_definition(&self) -> HookDefinition {
        let mut def = HookDefinition {
            hook_type: Some(self.hook_type.clone()),
            command: Some(self.command.clone()),
            ..Default::default()
        };
        if let Some(timeout) = self.timeout {
            def.additional_properties
                .insert("timeout".to_string(), serde_json::json!(timeout));
        }
        def
    }
}

#[derive(Debug, Clone, PartialEq)]
pub struct EditableHookGroup {
    pub id: Uuid,
    pub hooks: Vec<EditableHookDefinition>,
    pub matcher: Option<String>,
}

impl EditableHookGroup {
    pub fn new(matcher: Option<String>) -> Self {
        Self {
            id: Uuid::new_v4(),
            hooks: Vec::new(),
            matcher,
        }
    }

    pub fn from_group(group: &HookGroup) -> Self {
        let hooks = group
            .hooks
            .as_ref()
            .map(|h| {
                h.iter()
                    .map(EditableHookDefinition::from_definition)
                    .collect()
            })
            .unwrap_or_default();
        Self {
            id: Uuid::new_v4(),
            hooks,
            matcher: group.matcher.clone(),
        }
    }

    pub fn to_group(&self) -> HookGroup {
        let hooks: Vec<HookDefinition> = self.hooks.iter().map(|h| h.to_definition()).collect();
        HookGroup {
            matcher: self.matcher.clone(),
            hooks: if hooks.is_empty() { None } else { Some(hooks) },
            ..Default::default()
        }
    }
}

pub struct HookTemplate {
    pub name: &'static str,
    pub description: &'static str,
    pub event: HookEvent,
    pub matcher: Option<&'static str>,
    pub commands: &'static [&'static str],
}

pub static HOOK_TEMPLATES: &[HookTemplate] = &[
    HookTemplate {
        name: "Format Python",
        description: "Run black formatter after editing Python files",
        event: HookEvent::PostToolUse,
        matcher: Some("Edit(*.py)"),
        commands: &["black --quiet $FILEPATH"],
    },
    HookTemplate {
        name: "Lint TypeScript",
        description: "Run ESLint after editing TypeScript files",
        event: HookEvent::PostToolUse,
        matcher: Some("Edit(*.ts)"),
        commands: &["npx eslint --fix $FILEPATH"],
    },
    HookTemplate {
        name: "Verify Build",
        description: "Check that the project builds after edits",
        event: HookEvent::PostToolUse,
        matcher: Some("Edit"),
        commands: &["npm run build --quiet"],
    },
    HookTemplate {
        name: "Approve Bash",
        description: "Log bash commands before execution",
        event: HookEvent::PreToolUse,
        matcher: Some("Bash"),
        commands: &["echo \"Running: $TOOL_INPUT\""],
    },
    HookTemplate {
        name: "Notify on Stop",
        description: "Send a notification when Claude finishes",
        event: HookEvent::Stop,
        matcher: None,
        commands: &["osascript -e 'display notification \"Claude finished\" with title \"Fig\"'"],
    },
    HookTemplate {
        name: "Run Tests",
        description: "Run tests after writing test files",
        event: HookEvent::PostToolUse,
        matcher: Some("Write(*test*)"),
        commands: &["npm test -- --bail"],
    },
];

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_hook_event_methods() {
        for event in HookEvent::all() {
            assert!(!event.display_name().is_empty());
            assert!(!event.key().is_empty());
            assert!(!event.description().is_empty());
        }
        assert_eq!(HookEvent::all().len(), 4);
    }

    #[test]
    fn test_supports_matcher() {
        assert!(HookEvent::PreToolUse.supports_matcher());
        assert!(HookEvent::PostToolUse.supports_matcher());
        assert!(!HookEvent::Notification.supports_matcher());
        assert!(!HookEvent::Stop.supports_matcher());
    }

    #[test]
    fn test_editable_hook_definition_round_trip() {
        let def = HookDefinition {
            hook_type: Some("command".to_string()),
            command: Some("npm run lint".to_string()),
            ..Default::default()
        };
        let editable = EditableHookDefinition::from_definition(&def);
        let result = editable.to_definition();
        assert_eq!(result.hook_type, def.hook_type);
        assert_eq!(result.command, def.command);
    }

    #[test]
    fn test_editable_hook_group_round_trip() {
        let group = HookGroup {
            matcher: Some("Bash(*)".to_string()),
            hooks: Some(vec![HookDefinition {
                hook_type: Some("command".to_string()),
                command: Some("echo test".to_string()),
                ..Default::default()
            }]),
            ..Default::default()
        };
        let editable = EditableHookGroup::from_group(&group);
        assert_eq!(editable.matcher, Some("Bash(*)".to_string()));
        assert_eq!(editable.hooks.len(), 1);

        let result = editable.to_group();
        assert_eq!(result.matcher, group.matcher);
        assert_eq!(result.hooks.as_ref().unwrap().len(), 1);
    }

    #[test]
    fn test_unique_ids() {
        let h1 = EditableHookDefinition::new("cmd1".to_string());
        let h2 = EditableHookDefinition::new("cmd2".to_string());
        assert_ne!(h1.id, h2.id);

        let g1 = EditableHookGroup::new(None);
        let g2 = EditableHookGroup::new(None);
        assert_ne!(g1.id, g2.id);
    }

    #[test]
    fn test_templates_non_empty() {
        assert!(HOOK_TEMPLATES.len() >= 6);
        for template in HOOK_TEMPLATES {
            assert!(!template.name.is_empty());
            assert!(!template.commands.is_empty());
        }
    }
}
