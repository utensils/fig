use std::collections::HashMap;

use fig_core::models::{EditableHookGroup, EditingTarget, HookEvent, HOOK_TEMPLATES};
use iced::widget::{button, column, container, row, scrollable, text, text_input};
use iced::{Element, Length, Padding};

use crate::styles;
use crate::Message;

#[derive(Debug, Clone, PartialEq)]
pub struct HooksEditorState {
    pub active_event: HookEvent,
    pub groups: HashMap<HookEvent, Vec<EditableHookGroup>>,
    pub editing_target: EditingTarget,
}

impl Default for HooksEditorState {
    fn default() -> Self {
        Self {
            active_event: HookEvent::PreToolUse,
            groups: HashMap::new(),
            editing_target: EditingTarget::Global,
        }
    }
}

pub fn hooks_editor_view<'a>(state: &'a HooksEditorState) -> Element<'a, Message> {
    // Event tabs
    let mut event_tabs = row![].spacing(0);
    for &event in HookEvent::all() {
        let is_active = event == state.active_event;
        let text_color = if is_active {
            styles::ACCENT
        } else {
            styles::TEXT_SECONDARY
        };
        event_tabs = event_tabs.push(
            button(
                container(
                    text(event.display_name().to_string())
                        .size(12)
                        .color(text_color),
                )
                .padding(Padding::new(8.0).left(12.0).right(12.0)),
            )
            .on_press(Message::HooksSelectEvent(event))
            .padding(0)
            .style(move |_theme: &iced::Theme, _status| button::Style {
                background: None,
                text_color,
                border: if is_active {
                    iced::Border {
                        color: styles::ACCENT,
                        width: 0.0,
                        radius: 0.into(),
                    }
                } else {
                    iced::Border::default()
                },
                shadow: iced::Shadow::default(),
            }),
        );
    }

    // Description for active event
    let event_desc = text(state.active_event.description())
        .size(12)
        .color(styles::TEXT_SECONDARY);

    // Template quick-add buttons (filtered by active event)
    let mut templates_row = row![].spacing(6);
    for template in HOOK_TEMPLATES {
        if template.event == state.active_event {
            let name = template.name.to_string();
            templates_row = templates_row.push(
                button(text(template.name).size(10))
                    .on_press(Message::HooksApplyTemplate(name))
                    .padding(Padding::new(2.0).left(6.0).right(6.0))
                    .style(|_theme: &iced::Theme, _status| button::Style {
                        background: Some(styles::SELECTED_BG.into()),
                        text_color: styles::ACCENT,
                        border: iced::Border {
                            radius: 3.0.into(),
                            ..Default::default()
                        },
                        shadow: iced::Shadow::default(),
                    }),
            );
        }
    }

    // Add Group button
    let add_group_btn = button(text("Add Group").size(12))
        .on_press(Message::HooksAddGroup)
        .padding(Padding::new(4.0).left(12.0).right(12.0));

    // Groups list for active event
    let active_groups = state.groups.get(&state.active_event);
    let mut groups_col = column![].spacing(8);

    if let Some(groups) = active_groups {
        for group in groups {
            groups_col = groups_col.push(group_card(group, state.active_event));
        }
    }

    if active_groups.map(|g| g.is_empty()).unwrap_or(true) {
        groups_col = groups_col.push(
            container(
                text("No hook groups for this event. Add a group or use a template.")
                    .size(13)
                    .color(styles::TEXT_SECONDARY),
            )
            .padding(20)
            .width(Length::Fill)
            .center_x(Length::Fill),
        );
    }

    // Target picker
    let target_options: Vec<EditingTarget> = if state.editing_target == EditingTarget::Global {
        vec![EditingTarget::Global]
    } else {
        EditingTarget::project_targets().to_vec()
    };

    let target_picker = iced::widget::pick_list(
        target_options,
        Some(state.editing_target),
        Message::HooksChangeTarget,
    )
    .text_size(13);

    container(
        column![
            text("Hooks").size(20).color(styles::TEXT_PRIMARY),
            text("Configure lifecycle hooks that run during Claude Code operations.")
                .size(13)
                .color(styles::TEXT_SECONDARY),
            target_picker,
            event_tabs,
            event_desc,
            row![
                text("Templates").size(12).color(styles::TEXT_SECONDARY),
                templates_row,
            ]
            .spacing(8)
            .align_y(iced::Alignment::Center),
            add_group_btn,
            scrollable(groups_col).height(Length::Fill),
        ]
        .spacing(12),
    )
    .padding(24)
    .width(Length::Fill)
    .height(Length::Fill)
    .into()
}

fn group_card<'a>(group: &'a EditableHookGroup, event: HookEvent) -> Element<'a, Message> {
    let group_id = group.id;
    let group_id_for_add = group.id;

    let mut card = column![].spacing(6);

    // Group header: matcher + remove button
    let mut header = row![].spacing(8).align_y(iced::Alignment::Center);

    if event.supports_matcher() {
        let matcher_value = group.matcher.as_deref().unwrap_or("");
        header = header.push(
            text_input("Matcher pattern (e.g. Bash(*))", matcher_value)
                .on_input(move |s| Message::HooksUpdateMatcher(group_id, s))
                .size(12)
                .width(Length::Fill),
        );
    } else {
        header = header.push(iced::widget::horizontal_space());
    }

    header = header.push(
        button(text("x").size(11))
            .on_press(Message::HooksRemoveGroup(group_id))
            .padding(Padding::new(2.0).left(6.0).right(6.0))
            .style(|_theme: &iced::Theme, _status| button::Style {
                background: None,
                text_color: styles::TEXT_SECONDARY,
                border: iced::Border::default(),
                shadow: iced::Shadow::default(),
            }),
    );

    card = card.push(header);

    // Hooks in this group
    for hook in &group.hooks {
        let hook_id = hook.id;
        let hook_row = row![
            text_input("Command", &hook.command)
                .on_input(move |s| Message::HooksUpdateHookCommand(group_id, hook_id, s))
                .size(12)
                .width(Length::Fill),
            button(text("x").size(10))
                .on_press(Message::HooksRemoveHook(group_id, hook_id))
                .padding(Padding::new(2.0).left(4.0).right(4.0))
                .style(|_theme: &iced::Theme, _status| button::Style {
                    background: None,
                    text_color: styles::TEXT_SECONDARY,
                    border: iced::Border::default(),
                    shadow: iced::Shadow::default(),
                }),
        ]
        .spacing(4)
        .align_y(iced::Alignment::Center);

        card = card.push(hook_row);
    }

    // Add hook button
    card = card.push(
        button(text("+ Add Hook").size(11))
            .on_press(Message::HooksAddHook(group_id_for_add))
            .padding(Padding::new(2.0).left(8.0).right(8.0))
            .style(|_theme: &iced::Theme, _status| button::Style {
                background: None,
                text_color: styles::ACCENT,
                border: iced::Border::default(),
                shadow: iced::Shadow::default(),
            }),
    );

    container(card)
        .padding(Padding::new(8.0).left(12.0).right(12.0))
        .width(Length::Fill)
        .style(|_theme: &iced::Theme| container::Style {
            background: Some(styles::SELECTED_BG.into()),
            border: iced::Border {
                radius: 6.0.into(),
                ..Default::default()
            },
            ..Default::default()
        })
        .into()
}
