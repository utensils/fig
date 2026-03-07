use fig_core::models::{GlobalSettingsTab, NavigationSelection, ProjectDetailTab};
use iced::widget::{button, column, container, row, text};
use iced::{Element, Length, Padding};

use crate::styles;
use crate::views::attribution_editor::{attribution_editor_view, AttributionEditorState};
use crate::views::environment_editor::{environment_editor_view, EnvironmentEditorState};
use crate::views::permissions_editor::{permissions_editor_view, PermissionsEditorState};
use crate::Message;

pub fn detail_view<'a>(
    selection: &'a NavigationSelection,
    global_tab: GlobalSettingsTab,
    project_tab: ProjectDetailTab,
    permissions_state: &'a PermissionsEditorState,
    environment_state: &'a EnvironmentEditorState,
    attribution_state: &'a AttributionEditorState,
) -> Element<'a, Message> {
    let content = match selection {
        NavigationSelection::GlobalSettings => global_settings_view(
            global_tab,
            permissions_state,
            environment_state,
            attribution_state,
        ),
        NavigationSelection::Project(path) => project_detail_view(
            path,
            project_tab,
            permissions_state,
            environment_state,
            attribution_state,
        ),
    };

    container(content)
        .width(Length::Fill)
        .height(Length::Fill)
        .style(|_theme: &iced::Theme| container::Style {
            background: Some(styles::DETAIL_BG.into()),
            ..Default::default()
        })
        .into()
}

fn global_settings_view<'a>(
    active_tab: GlobalSettingsTab,
    permissions_state: &'a PermissionsEditorState,
    environment_state: &'a EnvironmentEditorState,
    attribution_state: &'a AttributionEditorState,
) -> Element<'a, Message> {
    let tabs = tab_bar(
        GlobalSettingsTab::all(),
        active_tab,
        |tab| tab.title().to_string(),
        Message::SelectGlobalTab,
    );

    let body = match active_tab {
        GlobalSettingsTab::Permissions => permissions_editor_view(permissions_state),
        GlobalSettingsTab::Environment => environment_editor_view(environment_state),
        GlobalSettingsTab::McpServers => {
            placeholder_content("MCP Servers", "Manage MCP server configs")
        }
        GlobalSettingsTab::Advanced => attribution_editor_view(attribution_state),
    };

    column![tabs, body]
        .spacing(0)
        .width(Length::Fill)
        .height(Length::Fill)
        .into()
}

fn project_detail_view<'a>(
    path: &str,
    active_tab: ProjectDetailTab,
    permissions_state: &'a PermissionsEditorState,
    environment_state: &'a EnvironmentEditorState,
    attribution_state: &'a AttributionEditorState,
) -> Element<'a, Message> {
    let project_name = std::path::Path::new(path)
        .file_name()
        .and_then(|n| n.to_str())
        .unwrap_or(path);

    let header = container(
        text(project_name.to_string())
            .size(18)
            .color(styles::TEXT_PRIMARY),
    )
    .padding(Padding::new(16.0).left(24.0).right(24.0));

    let tabs = tab_bar(
        ProjectDetailTab::all(),
        active_tab,
        |tab| tab.title().to_string(),
        Message::SelectProjectTab,
    );

    let body = match active_tab {
        ProjectDetailTab::Permissions => permissions_editor_view(permissions_state),
        ProjectDetailTab::Environment => environment_editor_view(environment_state),
        ProjectDetailTab::McpServers => placeholder_content("MCP Servers", "Project MCP servers"),
        ProjectDetailTab::Hooks => placeholder_content("Hooks", "Lifecycle hooks configuration"),
        ProjectDetailTab::ClaudeMd => placeholder_content("CLAUDE.md", "Project instructions"),
        ProjectDetailTab::EffectiveConfig => {
            placeholder_content("Effective Config", "Merged configuration view")
        }
        ProjectDetailTab::HealthCheck => placeholder_content("Health", "Server health checks"),
        ProjectDetailTab::Advanced => attribution_editor_view(attribution_state),
    };

    column![header, tabs, body]
        .spacing(0)
        .width(Length::Fill)
        .height(Length::Fill)
        .into()
}

fn tab_bar<'a, T: Copy + PartialEq>(
    tabs: &[T],
    active: T,
    label_fn: impl Fn(T) -> String,
    message_fn: impl Fn(T) -> Message + 'a,
) -> Element<'a, Message> {
    let mut tab_row = row![].spacing(0);

    for &tab in tabs {
        let is_active = tab == active;
        let label = label_fn(tab);
        let msg = message_fn(tab);

        let text_color = if is_active {
            styles::ACCENT
        } else {
            styles::TEXT_SECONDARY
        };

        let tab_btn = button(
            container(text(label).size(12).color(text_color))
                .padding(Padding::new(8.0).left(16.0).right(16.0)),
        )
        .on_press(msg)
        .padding(0)
        .style(move |_theme: &iced::Theme, _status| {
            let border = if is_active {
                iced::Border {
                    color: styles::ACCENT,
                    width: 0.0,
                    radius: 0.into(),
                }
            } else {
                iced::Border::default()
            };
            button::Style {
                background: None,
                text_color,
                border,
                shadow: iced::Shadow::default(),
            }
        });

        tab_row = tab_row.push(tab_btn);
    }

    let bar = container(tab_row)
        .padding(Padding::new(0.0).left(24.0).right(24.0))
        .width(Length::Fill)
        .style(|_theme: &iced::Theme| container::Style {
            border: iced::Border {
                color: styles::DIVIDER,
                width: 1.0,
                radius: 0.into(),
            },
            ..Default::default()
        });

    bar.into()
}

fn placeholder_content<'a>(title: &str, description: &str) -> Element<'a, Message> {
    container(
        column![
            text(title.to_string()).size(20).color(styles::TEXT_PRIMARY),
            text(description.to_string())
                .size(14)
                .color(styles::TEXT_SECONDARY),
        ]
        .spacing(8),
    )
    .padding(24)
    .width(Length::Fill)
    .height(Length::Fill)
    .into()
}
