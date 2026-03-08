use std::fmt;

use crate::models::ConfigSource;

#[derive(Debug, Clone, PartialEq, Eq, Hash)]
pub enum NavigationSelection {
    GlobalSettings,
    Project(String),
}

impl NavigationSelection {
    pub fn project_path(&self) -> Option<&str> {
        match self {
            Self::Project(path) => Some(path),
            _ => None,
        }
    }

    pub fn is_global_settings(&self) -> bool {
        matches!(self, Self::GlobalSettings)
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash)]
pub enum GlobalSettingsTab {
    Permissions,
    Environment,
    McpServers,
    Advanced,
}

impl GlobalSettingsTab {
    pub fn title(&self) -> &str {
        match self {
            Self::Permissions => "Permissions",
            Self::Environment => "Environment",
            Self::McpServers => "MCP Servers",
            Self::Advanced => "Advanced",
        }
    }

    pub fn all() -> &'static [GlobalSettingsTab] {
        &[
            Self::Permissions,
            Self::Environment,
            Self::McpServers,
            Self::Advanced,
        ]
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash)]
pub enum ProjectDetailTab {
    Permissions,
    Environment,
    McpServers,
    Hooks,
    ClaudeMd,
    EffectiveConfig,
    HealthCheck,
    Advanced,
}

impl ProjectDetailTab {
    pub fn title(&self) -> &str {
        match self {
            Self::Permissions => "Permissions",
            Self::Environment => "Environment",
            Self::McpServers => "MCP Servers",
            Self::Hooks => "Hooks",
            Self::ClaudeMd => "CLAUDE.md",
            Self::EffectiveConfig => "Effective Config",
            Self::HealthCheck => "Health",
            Self::Advanced => "Advanced",
        }
    }

    pub fn all() -> &'static [ProjectDetailTab] {
        &[
            Self::Permissions,
            Self::Environment,
            Self::McpServers,
            Self::Hooks,
            Self::ClaudeMd,
            Self::EffectiveConfig,
            Self::HealthCheck,
            Self::Advanced,
        ]
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash)]
pub enum EditingTarget {
    Global,
    ProjectShared,
    ProjectLocal,
}

impl EditingTarget {
    pub fn label(&self) -> &str {
        match self {
            Self::Global => "Global (settings.json)",
            Self::ProjectShared => "Shared (settings.json)",
            Self::ProjectLocal => "Local (settings.local.json)",
        }
    }

    pub fn description(&self) -> &str {
        match self {
            Self::Global => "Applies to all projects",
            Self::ProjectShared => "Committed to git, shared with team",
            Self::ProjectLocal => "Git-ignored, local overrides",
        }
    }

    pub fn source(&self) -> ConfigSource {
        match self {
            Self::Global => ConfigSource::Global,
            Self::ProjectShared => ConfigSource::ProjectShared,
            Self::ProjectLocal => ConfigSource::ProjectLocal,
        }
    }

    pub fn project_targets() -> &'static [EditingTarget] {
        &[Self::ProjectShared, Self::ProjectLocal]
    }
}

impl fmt::Display for EditingTarget {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        write!(f, "{}", self.label())
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_navigation_selection_global() {
        let sel = NavigationSelection::GlobalSettings;
        assert!(sel.is_global_settings());
        assert_eq!(sel.project_path(), None);
    }

    #[test]
    fn test_navigation_selection_project() {
        let sel = NavigationSelection::Project("/my/project".to_string());
        assert!(!sel.is_global_settings());
        assert_eq!(sel.project_path(), Some("/my/project"));
    }

    #[test]
    fn test_navigation_selection_equality() {
        let a = NavigationSelection::Project("/a".to_string());
        let b = NavigationSelection::Project("/a".to_string());
        assert_eq!(a, b);
        assert_ne!(a, NavigationSelection::GlobalSettings);
    }

    #[test]
    fn test_global_settings_tab_titles() {
        assert_eq!(GlobalSettingsTab::Permissions.title(), "Permissions");
        assert_eq!(GlobalSettingsTab::McpServers.title(), "MCP Servers");
        assert_eq!(GlobalSettingsTab::all().len(), 4);
    }

    #[test]
    fn test_project_detail_tab_titles() {
        assert_eq!(ProjectDetailTab::Hooks.title(), "Hooks");
        assert_eq!(ProjectDetailTab::ClaudeMd.title(), "CLAUDE.md");
        assert_eq!(ProjectDetailTab::HealthCheck.title(), "Health");
        assert_eq!(ProjectDetailTab::all().len(), 8);
    }

    #[test]
    fn test_editing_target_label() {
        assert_eq!(EditingTarget::Global.label(), "Global (settings.json)");
        assert_eq!(
            EditingTarget::ProjectShared.label(),
            "Shared (settings.json)"
        );
        assert_eq!(
            EditingTarget::ProjectLocal.label(),
            "Local (settings.local.json)"
        );
    }

    #[test]
    fn test_editing_target_source() {
        assert_eq!(EditingTarget::Global.source(), ConfigSource::Global);
        assert_eq!(
            EditingTarget::ProjectShared.source(),
            ConfigSource::ProjectShared
        );
        assert_eq!(
            EditingTarget::ProjectLocal.source(),
            ConfigSource::ProjectLocal
        );
    }

    #[test]
    fn test_editing_target_project_targets() {
        let targets = EditingTarget::project_targets();
        assert_eq!(targets.len(), 2);
        assert_eq!(targets[0], EditingTarget::ProjectShared);
        assert_eq!(targets[1], EditingTarget::ProjectLocal);
    }

    #[test]
    fn test_editing_target_display() {
        assert_eq!(
            format!("{}", EditingTarget::Global),
            "Global (settings.json)"
        );
    }
}
