use std::fmt;

#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash)]
pub enum ConfigSource {
    Global,
    ProjectShared,
    ProjectLocal,
}

impl ConfigSource {
    pub fn label(&self) -> &'static str {
        match self {
            Self::Global => "Global",
            Self::ProjectShared => "Project (shared)",
            Self::ProjectLocal => "Project (local)",
        }
    }

    pub fn precedence(&self) -> u8 {
        match self {
            Self::Global => 0,
            Self::ProjectShared => 1,
            Self::ProjectLocal => 2,
        }
    }
}

impl fmt::Display for ConfigSource {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        write!(f, "{}", self.label())
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_config_source_precedence() {
        assert_eq!(ConfigSource::Global.precedence(), 0);
        assert_eq!(ConfigSource::ProjectShared.precedence(), 1);
        assert_eq!(ConfigSource::ProjectLocal.precedence(), 2);
        assert!(ConfigSource::ProjectLocal.precedence() > ConfigSource::Global.precedence());
    }

    #[test]
    fn test_config_source_display() {
        assert_eq!(format!("{}", ConfigSource::Global), "Global");
        assert_eq!(
            format!("{}", ConfigSource::ProjectShared),
            "Project (shared)"
        );
        assert_eq!(
            format!("{}", ConfigSource::ProjectLocal),
            "Project (local)"
        );
    }

    #[test]
    fn test_config_source_label() {
        assert_eq!(ConfigSource::Global.label(), "Global");
        assert_eq!(ConfigSource::ProjectShared.label(), "Project (shared)");
        assert_eq!(ConfigSource::ProjectLocal.label(), "Project (local)");
    }
}
