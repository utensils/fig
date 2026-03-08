use fig_core::models::{MCPServerFormData, MCPServerType, ValidationError};
use iced::widget::{button, column, container, pick_list, row, text, text_input};
use iced::{Element, Length, Padding};

use crate::styles;
use crate::Message;

pub fn mcp_server_form_view<'a>(
    form: &'a MCPServerFormData,
    errors: &'a [ValidationError],
) -> Element<'a, Message> {
    let title = if form.is_editing {
        "Edit Server"
    } else {
        "Add Server"
    };

    let type_options = vec![MCPServerType::Stdio, MCPServerType::Sse];

    let mut content = column![
        text(title).size(20).color(styles::TEXT_PRIMARY),
        // Name field
        text("Name").size(12).color(styles::TEXT_SECONDARY),
        text_input("Server name", &form.name)
            .on_input(Message::MCPFormUpdateName)
            .size(13),
    ]
    .spacing(8)
    .width(Length::Fill);

    content = push_field_errors(content, errors, "name");

    // Server type picker
    content = content
        .push(text("Type").size(12).color(styles::TEXT_SECONDARY))
        .push(
            pick_list(
                type_options,
                Some(form.server_type),
                Message::MCPFormChangeType,
            )
            .text_size(13),
        );

    match form.server_type {
        MCPServerType::Stdio => {
            content = content
                .push(text("Command").size(12).color(styles::TEXT_SECONDARY))
                .push(
                    text_input("e.g. npx, node, python", &form.command)
                        .on_input(Message::MCPFormUpdateCommand)
                        .size(13),
                );
            content = push_field_errors(content, errors, "command");

            content = content
                .push(
                    text("Arguments (one per line)")
                        .size(12)
                        .color(styles::TEXT_SECONDARY),
                )
                .push(
                    text_input("-y\n@modelcontextprotocol/server-github", &form.args_text)
                        .on_input(Message::MCPFormUpdateArgs)
                        .size(13),
                );

            content = content
                .push(
                    text("Environment Variables (KEY=VALUE per line)")
                        .size(12)
                        .color(styles::TEXT_SECONDARY),
                )
                .push(
                    text_input("GITHUB_TOKEN=your-token", &form.env_text)
                        .on_input(Message::MCPFormUpdateEnv)
                        .size(13),
                );
        }
        MCPServerType::Sse => {
            content = content
                .push(text("URL").size(12).color(styles::TEXT_SECONDARY))
                .push(
                    text_input("https://mcp.example.com/api", &form.url)
                        .on_input(Message::MCPFormUpdateUrl)
                        .size(13),
                );
            content = push_field_errors(content, errors, "url");
        }
    }

    // Buttons
    let save_btn = button(text("Save").size(13))
        .on_press(Message::MCPFormSave)
        .padding(Padding::new(6.0).left(16.0).right(16.0));

    let cancel_btn = button(text("Cancel").size(13))
        .on_press(Message::MCPFormCancel)
        .padding(Padding::new(6.0).left(16.0).right(16.0))
        .style(|_theme: &iced::Theme, _status| button::Style {
            background: None,
            text_color: styles::TEXT_SECONDARY,
            border: iced::Border {
                radius: 4.0.into(),
                color: styles::DIVIDER,
                width: 1.0,
            },
            shadow: iced::Shadow::default(),
        });

    content = content.push(
        row![save_btn, cancel_btn]
            .spacing(8)
            .padding(Padding::new(8.0).top(4.0)),
    );

    container(content)
        .padding(24)
        .width(Length::Fill)
        .height(Length::Fill)
        .into()
}

fn push_field_errors<'a>(
    col: iced::widget::Column<'a, Message>,
    errors: &[ValidationError],
    field: &str,
) -> iced::widget::Column<'a, Message> {
    let mut result = col;
    for error in errors.iter().filter(|e| e.field == field) {
        result = result.push(
            text(error.message.clone())
                .size(11)
                .color(iced::Color::from_rgb(0.9, 0.3, 0.3)),
        );
    }
    result
}
