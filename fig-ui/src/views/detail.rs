use fig_core::models::{GlobalSettingsTab, NavigationSelection, ProjectDetailTab};
use iced::widget::{button, column, container, row, text};
use iced::{Element, Length, Padding};

use crate::styles;
use crate::Message;

pub fn detail_view<'a>(
    selection: &'a NavigationSelection,
    global_tab: GlobalSettingsTab,
    project_tab: ProjectDetailTab,
) -> Element<'a, Message> {
    let content = match selection {
        NavigationSelection::GlobalSettings => global_settings_view(global_tab),
        NavigationSelection::Project(path) => project_detail_view(path, project_tab),
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

fn global_settings_view(active_tab: GlobalSettingsTab) -> Element<'static, Message> {
    let tabs = tab_bar(
        GlobalSettingsTab::all(),
        active_tab,
        |tab| tab.title().to_string(),
        Message::SelectGlobalTab,
    );

    let body = match active_tab {
        GlobalSettingsTab::Permissions => {
            placeholder_content("Permissions", "Manage tool permissions")
        }
        GlobalSettingsTab::Environment => {
            placeholder_content("Environment", "Configure environment variables")
        }
        GlobalSettingsTab::McpServers => {
            placeholder_content("MCP Servers", "Manage MCP server configs")
        }
        GlobalSettingsTab::Advanced => placeholder_content("Advanced", "Advanced settings"),
    };

    column![tabs, body]
        .spacing(0)
        .width(Length::Fill)
        .height(Length::Fill)
        .into()
}

fn project_detail_view<'a>(path: &str, active_tab: ProjectDetailTab) -> Element<'a, Message> {
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
        ProjectDetailTab::Permissions => {
            placeholder_content("Permissions", "Project permission rules")
        }
        ProjectDetailTab::Environment => {
            placeholder_content("Environment", "Project environment variables")
        }
        ProjectDetailTab::McpServers => placeholder_content("MCP Servers", "Project MCP servers"),
        ProjectDetailTab::Hooks => placeholder_content("Hooks", "Lifecycle hooks configuration"),
        ProjectDetailTab::ClaudeMd => placeholder_content("CLAUDE.md", "Project instructions"),
        ProjectDetailTab::EffectiveConfig => {
            placeholder_content("Effective Config", "Merged configuration view")
        }
        ProjectDetailTab::HealthCheck => placeholder_content("Health", "Server health checks"),
        ProjectDetailTab::Advanced => placeholder_content("Advanced", "Advanced project settings"),
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
