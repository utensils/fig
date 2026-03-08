use fig_core::models::{ConfigSource, MergedSettings};
use iced::widget::{column, container, row, scrollable, text};
use iced::{Color, Element, Length, Padding};

use crate::styles;
use crate::Message;

#[derive(Debug, Clone, Default)]
#[allow(dead_code)]
pub struct EffectiveConfigViewState {
    pub settings: Option<MergedSettings>,
    pub is_loading: bool,
}

fn source_color(source: ConfigSource) -> Color {
    match source {
        ConfigSource::Global => styles::TEXT_SECONDARY,
        ConfigSource::ProjectShared => Color::from_rgb(0.4, 0.6, 1.0),
        ConfigSource::ProjectLocal => Color::from_rgb(0.3, 0.8, 0.4),
    }
}

fn source_badge<'a>(source: ConfigSource) -> Element<'a, Message> {
    container(text(source.label()).size(9).color(source_color(source)))
        .padding(Padding::new(1.0).left(4.0).right(4.0))
        .style(move |_theme: &iced::Theme| container::Style {
            background: Some(Color::from_rgba(0.0, 0.0, 0.0, 0.3).into()),
            border: iced::Border {
                radius: 3.0.into(),
                ..Default::default()
            },
            ..Default::default()
        })
        .into()
}

pub fn effective_config_view<'a>(state: &'a EffectiveConfigViewState) -> Element<'a, Message> {
    let mut content = column![
        text("Effective Configuration")
            .size(20)
            .color(styles::TEXT_PRIMARY),
        text("Read-only view of merged settings from all configuration tiers.")
            .size(13)
            .color(styles::TEXT_SECONDARY),
    ]
    .spacing(12);

    let settings = match &state.settings {
        Some(s) => s,
        None => {
            content = content.push(
                container(
                    text("No merged configuration loaded.")
                        .size(13)
                        .color(styles::TEXT_SECONDARY),
                )
                .padding(20)
                .width(Length::Fill)
                .center_x(Length::Fill),
            );
            return container(content)
                .padding(24)
                .width(Length::Fill)
                .height(Length::Fill)
                .into();
        }
    };

    let mut sections = column![].spacing(16);

    // Permissions section
    sections = sections.push(section_header("Permissions"));
    if settings.permissions.allow.is_empty() && settings.permissions.deny.is_empty() {
        sections = sections.push(empty_placeholder("No permission rules configured."));
    } else {
        let mut perms_col = column![].spacing(4);
        for rule in &settings.permissions.allow {
            perms_col = perms_col.push(
                row![
                    text("Allow").size(11).color(Color::from_rgb(0.3, 0.8, 0.4)),
                    text(&rule.value).size(12).color(styles::TEXT_PRIMARY),
                    source_badge(rule.source),
                ]
                .spacing(8)
                .align_y(iced::Alignment::Center),
            );
        }
        for rule in &settings.permissions.deny {
            perms_col = perms_col.push(
                row![
                    text("Deny").size(11).color(Color::from_rgb(0.9, 0.3, 0.3)),
                    text(&rule.value).size(12).color(styles::TEXT_PRIMARY),
                    source_badge(rule.source),
                ]
                .spacing(8)
                .align_y(iced::Alignment::Center),
            );
        }
        sections = sections.push(perms_col);
    }

    // Environment section
    sections = sections.push(section_header("Environment Variables"));
    if settings.env.is_empty() {
        sections = sections.push(empty_placeholder("No environment variables configured."));
    } else {
        let mut env_col = column![].spacing(4);
        let mut keys: Vec<_> = settings.env.keys().collect();
        keys.sort();
        for key in keys {
            let mv = &settings.env[key];
            env_col = env_col.push(
                row![
                    text(key).size(12).color(styles::TEXT_PRIMARY),
                    text("=").size(12).color(styles::TEXT_SECONDARY),
                    text(&mv.value).size(12).color(styles::TEXT_SECONDARY),
                    source_badge(mv.source),
                ]
                .spacing(4)
                .align_y(iced::Alignment::Center),
            );
        }
        sections = sections.push(env_col);
    }

    // Hooks section
    sections = sections.push(section_header("Hooks"));
    let hook_events = settings.hooks.event_names();
    if hook_events.is_empty() {
        sections = sections.push(empty_placeholder("No hooks configured."));
    } else {
        let mut hooks_col = column![].spacing(6);
        for event in &hook_events {
            hooks_col = hooks_col.push(text(event.clone()).size(13).color(styles::ACCENT));
            if let Some(groups) = settings.hooks.groups(event) {
                for mv in groups {
                    let matcher_text = mv
                        .value
                        .matcher
                        .as_deref()
                        .map(|m| format!(" [{m}]"))
                        .unwrap_or_default();
                    let hook_count = mv.value.hooks.as_ref().map(|h| h.len()).unwrap_or(0);
                    hooks_col = hooks_col.push(
                        row![
                            text(format!("  {hook_count} hook(s){matcher_text}"))
                                .size(12)
                                .color(styles::TEXT_SECONDARY),
                            source_badge(mv.source),
                        ]
                        .spacing(8)
                        .align_y(iced::Alignment::Center),
                    );
                }
            }
        }
        sections = sections.push(hooks_col);
    }

    // Disallowed Tools section
    sections = sections.push(section_header("Disallowed Tools"));
    if settings.disallowed_tools.is_empty() {
        sections = sections.push(empty_placeholder("No tools are disallowed."));
    } else {
        let mut tools_col = column![].spacing(4);
        for tool in &settings.disallowed_tools {
            tools_col = tools_col.push(
                row![
                    text(&tool.value).size(12).color(styles::TEXT_PRIMARY),
                    source_badge(tool.source),
                ]
                .spacing(8)
                .align_y(iced::Alignment::Center),
            );
        }
        sections = sections.push(tools_col);
    }

    // Attribution section
    sections = sections.push(section_header("Attribution"));
    match &settings.attribution {
        Some(mv) => {
            let commits = mv.value.commits.unwrap_or(false);
            let prs = mv.value.pull_requests.unwrap_or(false);
            sections = sections.push(
                column![
                    row![
                        text(format!("Commits: {}", if commits { "Yes" } else { "No" }))
                            .size(12)
                            .color(styles::TEXT_PRIMARY),
                        source_badge(mv.source),
                    ]
                    .spacing(8)
                    .align_y(iced::Alignment::Center),
                    text(format!("Pull Requests: {}", if prs { "Yes" } else { "No" }))
                        .size(12)
                        .color(styles::TEXT_PRIMARY),
                ]
                .spacing(4),
            );
        }
        None => {
            sections = sections.push(empty_placeholder("No attribution settings configured."));
        }
    }

    content = content.push(scrollable(sections).height(Length::Fill));

    container(content)
        .padding(24)
        .width(Length::Fill)
        .height(Length::Fill)
        .into()
}

fn section_header<'a>(title: &str) -> Element<'a, Message> {
    text(title.to_string())
        .size(15)
        .color(styles::TEXT_PRIMARY)
        .into()
}

fn empty_placeholder<'a>(msg: &str) -> Element<'a, Message> {
    text(msg.to_string())
        .size(12)
        .color(styles::TEXT_SECONDARY)
        .into()
}
