use std::collections::BTreeMap;
use std::path::{Path, PathBuf};

use crate::models::discovered_project::DiscoveredProject;
use crate::models::ProjectEntry;

#[derive(Debug, Clone)]
pub struct ProjectGroup {
    pub parent_path: PathBuf,
    pub display_name: String,
    pub projects: Vec<ProjectEntry>,
}

impl ProjectGroup {
    pub fn new(parent_path: PathBuf, display_name: String, projects: Vec<ProjectEntry>) -> Self {
        Self {
            parent_path,
            display_name,
            projects,
        }
    }

    pub fn id(&self) -> &PathBuf {
        &self.parent_path
    }

    /// Groups discovered projects by their parent directory.
    ///
    /// Abbreviates parent paths relative to the home directory (e.g. `~/code`).
    pub fn group_by_directory(
        projects: &[DiscoveredProject],
        home_dir: Option<&Path>,
    ) -> Vec<ProjectGroup> {
        let mut groups_map: BTreeMap<PathBuf, Vec<&DiscoveredProject>> = BTreeMap::new();

        for project in projects {
            let parent = project
                .path
                .parent()
                .unwrap_or(Path::new("/"))
                .to_path_buf();
            groups_map.entry(parent).or_default().push(project);
        }

        groups_map
            .into_iter()
            .map(|(parent_path, members)| {
                let display_name = abbreviate_dir(&parent_path, home_dir);

                let project_entries = members
                    .into_iter()
                    .map(|dp| ProjectEntry {
                        path: Some(dp.path.to_string_lossy().to_string()),
                        ..Default::default()
                    })
                    .collect();

                ProjectGroup::new(parent_path, display_name, project_entries)
            })
            .collect()
    }
}

fn abbreviate_dir(path: &Path, home: Option<&Path>) -> String {
    if let Some(h) = home {
        if let Ok(relative) = path.strip_prefix(h) {
            if relative.as_os_str().is_empty() {
                return "~".to_string();
            }
            return format!("~/{}", relative.display());
        }
    }
    path.display().to_string()
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_new_group() {
        let group = ProjectGroup::new(
            PathBuf::from("/Users/sean/code"),
            "~/code".to_string(),
            vec![],
        );
        assert_eq!(group.parent_path, PathBuf::from("/Users/sean/code"));
        assert_eq!(group.display_name, "~/code");
        assert!(group.projects.is_empty());
    }

    #[test]
    fn test_id_is_parent_path() {
        let group = ProjectGroup::new(
            PathBuf::from("/Users/sean/projects"),
            "~/projects".to_string(),
            vec![],
        );
        assert_eq!(group.id(), &PathBuf::from("/Users/sean/projects"));
    }

    #[test]
    fn test_group_with_projects() {
        let entry = ProjectEntry {
            path: Some("/Users/sean/code/relay".to_string()),
            ..Default::default()
        };

        let group = ProjectGroup::new(
            PathBuf::from("/Users/sean/code"),
            "~/code".to_string(),
            vec![entry],
        );
        assert_eq!(group.projects.len(), 1);
    }

    #[test]
    fn test_group_by_directory() {
        let projects = vec![
            DiscoveredProject::new(
                PathBuf::from("/home/user/code/project-a"),
                "project-a".to_string(),
                true,
                false,
                false,
                false,
                None,
            ),
            DiscoveredProject::new(
                PathBuf::from("/home/user/code/project-b"),
                "project-b".to_string(),
                true,
                false,
                false,
                false,
                None,
            ),
            DiscoveredProject::new(
                PathBuf::from("/home/user/work/project-c"),
                "project-c".to_string(),
                true,
                false,
                false,
                false,
                None,
            ),
        ];

        let home = Path::new("/home/user");
        let groups = ProjectGroup::group_by_directory(&projects, Some(home));

        assert_eq!(groups.len(), 2);
        assert_eq!(groups[0].display_name, "~/code");
        assert_eq!(groups[0].projects.len(), 2);
        assert_eq!(groups[1].display_name, "~/work");
        assert_eq!(groups[1].projects.len(), 1);
    }

    #[test]
    fn test_group_by_directory_no_home() {
        let projects = vec![DiscoveredProject::new(
            PathBuf::from("/opt/projects/myapp"),
            "myapp".to_string(),
            true,
            false,
            false,
            false,
            None,
        )];

        let groups = ProjectGroup::group_by_directory(&projects, None);
        assert_eq!(groups.len(), 1);
        assert_eq!(groups[0].display_name, "/opt/projects");
    }

    #[test]
    fn test_abbreviate_dir_with_home() {
        let path = Path::new("/home/user/code");
        let home = Path::new("/home/user");
        assert_eq!(abbreviate_dir(path, Some(home)), "~/code");
    }

    #[test]
    fn test_abbreviate_dir_home_root() {
        let path = Path::new("/home/user");
        let home = Path::new("/home/user");
        assert_eq!(abbreviate_dir(path, Some(home)), "~");
    }

    #[test]
    fn test_abbreviate_dir_no_home() {
        let path = Path::new("/opt/data");
        assert_eq!(abbreviate_dir(path, None), "/opt/data");
    }
}
