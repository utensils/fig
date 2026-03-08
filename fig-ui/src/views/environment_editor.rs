use fig_core::models::{EditableEnvironmentVariable, EditingTarget, KNOWN_ENVIRONMENT_VARIABLES};
use iced::widget::{button, column, container, pick_list, row, scrollable, text, text_input};
use iced::{Element, Length, Padding};
use uuid::Uuid;

use crate::styles;
use crate::Message;

#[derive(Debug, Clone, PartialEq)]
pub struct EnvironmentEditorState {
    pub variables: Vec<EditableEnvironmentVariable>,
    pub editing_target: EditingTarget,
    pub new_key: String,
    pub new_value: String,
}

impl Default for EnvironmentEditorState {
    fn default() -> Self {
        Self {
            variables: Vec::new(),
            editing_target: EditingTarget::Global,
            new_key: String::new(),
            new_value: String::new(),
        }
    }
}

impl EnvironmentEditorState {
    pub fn add_variable(&mut self) {
        let key = self.new_key.trim().to_string();
        if key.is_empty() || key.contains(' ') {
            return;
        }
        self.variables.push(EditableEnvironmentVariable::new(
            key,
            self.new_value.clone(),
        ));
        self.new_key.clear();
        self.new_value.clear();
    }

    pub fn add_known_variable(&mut self, name: &str) {
        if self.variables.iter().any(|v| v.key == name) {
            return;
        }
        let default = KNOWN_ENVIRONMENT_VARIABLES
            .iter()
            .find(|v| v.name == name)
            .and_then(|v| v.default_value)
            .unwrap_or("")
            .to_string();
        self.variables
            .push(EditableEnvironmentVariable::new(name.to_string(), default));
    }

    pub fn remove_variable(&mut self, id: Uuid) {
        self.variables.retain(|v| v.id != id);
    }
}

pub fn environment_editor_view<'a>(state: &'a EnvironmentEditorState) -> Element<'a, Message> {
    let target_options: Vec<EditingTarget> = if state.editing_target == EditingTarget::Global {
        vec![EditingTarget::Global]
    } else {
        EditingTarget::project_targets().to_vec()
    };

    let target_picker = pick_list(
        target_options,
        Some(state.editing_target),
        Message::EnvChangeTarget,
    )
    .text_size(13);

    // Known variable suggestions
    let mut known_row = row![].spacing(6);
    for var in KNOWN_ENVIRONMENT_VARIABLES {
        let name = var.name.to_string();
        let already_set = state.variables.iter().any(|v| v.key == var.name);
        if !already_set {
            known_row = known_row.push(
                button(text(var.name).size(10))
                    .on_press(Message::EnvAddKnown(name))
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

    // New variable input
    let key_input = text_input("Variable name", &state.new_key)
        .on_input(Message::EnvNewKeyInput)
        .size(13)
        .width(200);

    let value_input = text_input("Value", &state.new_value)
        .on_input(Message::EnvNewValueInput)
        .on_submit(Message::EnvAddVariable)
        .size(13)
        .width(Length::Fill);

    let add_btn = button(text("Add").size(12))
        .on_press(Message::EnvAddVariable)
        .padding(Padding::new(4.0).left(12.0).right(12.0));

    let input_row = row![key_input, value_input, add_btn]
        .spacing(8)
        .width(Length::Fill);

    // Variables list
    let mut vars_col = column![].spacing(4);
    for var in &state.variables {
        let is_sensitive = EditableEnvironmentVariable::is_sensitive_key(&var.key);
        let display_value = if is_sensitive {
            "********".to_string()
        } else {
            var.value.clone()
        };

        let var_id = var.id;
        let var_row = row![
            text(&var.key)
                .size(13)
                .color(styles::TEXT_PRIMARY)
                .width(200),
            text(display_value)
                .size(13)
                .color(styles::TEXT_SECONDARY)
                .width(Length::Fill),
            button(text("x").size(11))
                .on_press(Message::EnvRemoveVariable(var_id))
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

        vars_col = vars_col.push(var_row);
    }

    container(
        column![
            text("Environment Variables")
                .size(20)
                .color(styles::TEXT_PRIMARY),
            text("Set environment variables that Claude Code inherits.")
                .size(13)
                .color(styles::TEXT_SECONDARY),
            target_picker,
            text("Known Variables")
                .size(12)
                .color(styles::TEXT_SECONDARY),
            scrollable(known_row),
            input_row,
            scrollable(vars_col).height(Length::Fill),
        ]
        .spacing(12),
    )
    .padding(24)
    .width(Length::Fill)
    .height(Length::Fill)
    .into()
}
