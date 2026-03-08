use fig_core::models::{EditablePermissionRule, EditingTarget, PermissionType, PERMISSION_PRESETS};
use iced::widget::{button, column, container, pick_list, row, scrollable, text, text_input};
use iced::{Element, Length, Padding};
use uuid::Uuid;

use crate::styles;
use crate::Message;

#[derive(Debug, Clone, PartialEq)]
pub struct PermissionsEditorState {
    pub rules: Vec<EditablePermissionRule>,
    pub editing_target: EditingTarget,
    pub new_rule_text: String,
    pub new_rule_type: PermissionType,
}

impl Default for PermissionsEditorState {
    fn default() -> Self {
        Self {
            rules: Vec::new(),
            editing_target: EditingTarget::Global,
            new_rule_text: String::new(),
            new_rule_type: PermissionType::Allow,
        }
    }
}

impl PermissionsEditorState {
    pub fn add_rule(&mut self) {
        let text = self.new_rule_text.trim().to_string();
        if text.is_empty() {
            return;
        }
        self.rules
            .push(EditablePermissionRule::new(text, self.new_rule_type));
        self.new_rule_text.clear();
    }

    pub fn remove_rule(&mut self, id: Uuid) {
        self.rules.retain(|r| r.id != id);
    }

    pub fn apply_preset(&mut self, preset_id: &str) {
        if let Some(preset) = PERMISSION_PRESETS.iter().find(|p| p.id == preset_id) {
            for &(rule, ptype) in preset.rules {
                if !self.rules.iter().any(|r| r.rule == rule) {
                    self.rules
                        .push(EditablePermissionRule::new(rule.to_string(), ptype));
                }
            }
        }
    }
}

pub fn permissions_editor_view<'a>(state: &'a PermissionsEditorState) -> Element<'a, Message> {
    let target_options: Vec<EditingTarget> = if state.editing_target == EditingTarget::Global {
        vec![EditingTarget::Global]
    } else {
        EditingTarget::project_targets().to_vec()
    };

    let target_picker = pick_list(
        target_options,
        Some(state.editing_target),
        Message::PermissionsChangeTarget,
    )
    .text_size(13);

    // Presets row
    let mut presets_row = row![].spacing(8);
    for preset in PERMISSION_PRESETS {
        let preset_id = preset.id.to_string();
        presets_row = presets_row.push(
            button(text(preset.name).size(11))
                .on_press(Message::PermissionsApplyPreset(preset_id))
                .padding(Padding::new(4.0).left(8.0).right(8.0))
                .style(|_theme: &iced::Theme, _status| button::Style {
                    background: Some(styles::SELECTED_BG.into()),
                    text_color: styles::TEXT_PRIMARY,
                    border: iced::Border {
                        radius: 4.0.into(),
                        ..Default::default()
                    },
                    shadow: iced::Shadow::default(),
                }),
        );
    }

    // New rule input
    let type_label = match state.new_rule_type {
        PermissionType::Allow => "Allow",
        PermissionType::Deny => "Deny",
    };
    let toggle_type = button(text(type_label).size(12))
        .on_press(Message::PermissionsToggleType)
        .padding(Padding::new(4.0).left(8.0).right(8.0));

    let input = text_input("Bash(npm run *), Read(src/**), etc.", &state.new_rule_text)
        .on_input(Message::PermissionsNewRuleInput)
        .on_submit(Message::PermissionsAddRule)
        .size(13);

    let add_btn = button(text("Add").size(12))
        .on_press(Message::PermissionsAddRule)
        .padding(Padding::new(4.0).left(12.0).right(12.0));

    let input_row = row![toggle_type, input, add_btn]
        .spacing(8)
        .width(Length::Fill);

    // Rules list
    let mut rules_col = column![].spacing(4);
    for rule in &state.rules {
        let type_color = match rule.permission_type {
            PermissionType::Allow => iced::Color::from_rgb(0.3, 0.8, 0.4),
            PermissionType::Deny => iced::Color::from_rgb(0.9, 0.3, 0.3),
        };
        let type_badge = container(
            text(rule.permission_type.label())
                .size(10)
                .color(type_color),
        )
        .padding(Padding::new(2.0).left(6.0).right(6.0))
        .style(move |_theme: &iced::Theme| container::Style {
            background: Some(iced::Color::from_rgba(0.0, 0.0, 0.0, 0.3).into()),
            border: iced::Border {
                radius: 3.0.into(),
                ..Default::default()
            },
            ..Default::default()
        });

        let rule_id = rule.id;
        let rule_row = row![
            type_badge,
            text(&rule.rule).size(13).color(styles::TEXT_PRIMARY),
            iced::widget::horizontal_space(),
            button(text("x").size(11))
                .on_press(Message::PermissionsRemoveRule(rule_id))
                .padding(Padding::new(2.0).left(6.0).right(6.0))
                .style(|_theme: &iced::Theme, _status| button::Style {
                    background: None,
                    text_color: styles::TEXT_SECONDARY,
                    border: iced::Border::default(),
                    shadow: iced::Shadow::default(),
                }),
        ]
        .spacing(8)
        .align_y(iced::Alignment::Center);

        rules_col = rules_col.push(rule_row);
    }

    container(
        column![
            text("Permissions").size(20).color(styles::TEXT_PRIMARY),
            text("Manage tool permission rules for Claude Code.")
                .size(13)
                .color(styles::TEXT_SECONDARY),
            target_picker,
            text("Quick Add Presets")
                .size(12)
                .color(styles::TEXT_SECONDARY),
            presets_row,
            input_row,
            scrollable(rules_col).height(Length::Fill),
        ]
        .spacing(12),
    )
    .padding(24)
    .width(Length::Fill)
    .height(Length::Fill)
    .into()
}
