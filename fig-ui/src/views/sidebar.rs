use fig_core::models::{abbreviate_dir, DiscoveredProject, NavigationSelection};
use iced::widget::{button, column, container, scrollable, text, Column};
use iced::{Color, Element, Length, Padding};
use std::collections::BTreeMap;
use std::path::{Path, PathBuf};

use crate::styles;
use crate::Message;

pub fn sidebar_view<'a>(
    projects: &'a [DiscoveredProject],
    selection: &'a NavigationSelection,
    group_by_directory: bool,
) -> Element<'a, Message> {
    let header = container(text("Fig").size(18).color(styles::TEXT_PRIMARY))
        .padding(Padding::new(16.0).left(20.0).right(20.0));

    let global_item = sidebar_item(
        "Global Settings",
        None,
        selection == &NavigationSelection::GlobalSettings,
        Message::SelectGlobalSettings,
    );

    let divider =
        container(text(""))
            .width(Length::Fill)
            .height(1)
            .style(|_theme: &iced::Theme| container::Style {
                background: Some(styles::DIVIDER.into()),
                ..Default::default()
            });

    let projects_header = container(text("Projects").size(11).color(styles::GROUP_HEADER_TEXT))
        .padding(Padding::new(8.0).left(20.0).right(20.0).bottom(4.0));

    let project_list = if group_by_directory {
        grouped_project_list(projects, selection)
    } else {
        flat_project_list(projects, selection)
    };

    let content = column![header, global_item, divider, projects_header, project_list]
        .width(styles::SIDEBAR_WIDTH);

    container(scrollable(content).height(Length::Fill))
        .width(styles::SIDEBAR_WIDTH)
        .height(Length::Fill)
        .style(|_theme: &iced::Theme| container::Style {
            background: Some(styles::SIDEBAR_BG.into()),
            ..Default::default()
        })
        .into()
}

fn flat_project_list<'a>(
    projects: &'a [DiscoveredProject],
    selection: &'a NavigationSelection,
) -> Element<'a, Message> {
    let mut col = Column::new();
    for project in projects {
        let path_str = project.path.to_string_lossy().to_string();
        let is_selected = selection == &NavigationSelection::Project(path_str.clone());
        col = col.push(sidebar_item(
            &project.display_name,
            Some(&project.path),
            is_selected,
            Message::SelectProject(path_str),
        ));
    }
    col.into()
}

fn grouped_project_list<'a>(
    projects: &'a [DiscoveredProject],
    selection: &'a NavigationSelection,
) -> Element<'a, Message> {
    let groups = group_projects_internal(projects);
    let mut col = Column::new();

    for group in &groups {
        col = col.push(
            container(
                text(group.display_name.clone())
                    .size(11)
                    .color(styles::GROUP_HEADER_TEXT),
            )
            .padding(Padding::new(8.0).left(20.0).right(20.0).bottom(2.0)),
        );

        for dp in &group.discovered {
            let path_str = dp.path.to_string_lossy().to_string();
            let is_selected = selection == &NavigationSelection::Project(path_str.clone());
            col = col.push(sidebar_item(
                &dp.display_name,
                Some(&dp.path),
                is_selected,
                Message::SelectProject(path_str),
            ));
        }
    }

    col.into()
}

/// Internal grouping struct for sidebar rendering that keeps DiscoveredProject refs.
struct SidebarProjectGroup<'a> {
    display_name: String,
    discovered: Vec<&'a DiscoveredProject>,
}

fn group_projects_internal(projects: &[DiscoveredProject]) -> Vec<SidebarProjectGroup<'_>> {
    let home = dirs::home_dir();
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
            let display_name = abbreviate_dir(&parent_path, home.as_deref());
            SidebarProjectGroup {
                display_name,
                discovered: members,
            }
        })
        .collect()
}

fn sidebar_item<'a>(
    label: &str,
    subtitle_path: Option<&Path>,
    is_selected: bool,
    on_press: Message,
) -> Element<'a, Message> {
    let bg = if is_selected {
        styles::SELECTED_BG
    } else {
        Color::TRANSPARENT
    };

    let text_color = if is_selected {
        styles::TEXT_PRIMARY
    } else {
        styles::TEXT_SECONDARY
    };

    let mut content = Column::new().push(text(label.to_string()).size(13).color(text_color));

    if let Some(path) = subtitle_path {
        let abbreviated = abbreviate_path(path);
        content = content.push(text(abbreviated).size(10).color(styles::TEXT_SECONDARY));
    }

    let inner = container(content.spacing(2))
        .padding(Padding::new(6.0).left(20.0).right(20.0))
        .width(Length::Fill)
        .style(move |_theme: &iced::Theme| container::Style {
            background: Some(bg.into()),
            ..Default::default()
        });

    button(inner)
        .on_press(on_press)
        .padding(0)
        .width(Length::Fill)
        .style(|_theme: &iced::Theme, _status| button::Style {
            background: None,
            text_color: styles::TEXT_PRIMARY,
            border: iced::Border::default(),
            shadow: iced::Shadow::default(),
        })
        .into()
}

fn abbreviate_path(path: &Path) -> String {
    abbreviate_dir(path, dirs::home_dir().as_deref())
}
