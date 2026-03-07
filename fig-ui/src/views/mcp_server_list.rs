use std::collections::HashSet;

use fig_core::models::{MCPServer, MCPServerFormData, ValidationError};
use iced::widget::{button, column, container, row, scrollable, text};
use iced::{Element, Length, Padding};

use super::mcp_copy_sheet::{CopySheetState, ImportSheetState};
use super::mcp_server_form::mcp_server_form_view;
use crate::styles;
use crate::Message;

#[derive(Debug, Clone, PartialEq, Default)]
pub struct MCPServerListState {
    pub servers: Vec<(String, MCPServer)>,
    pub expanded_servers: HashSet<String>,
    pub form: Option<MCPServerFormData>,
    pub validation_errors: Vec<ValidationError>,
    pub copy_sheet: Option<CopySheetState>,
    pub import_sheet: Option<ImportSheetState>,
}

pub fn mcp_server_list_view<'a>(state: &'a MCPServerListState) -> Element<'a, Message> {
    // If form is active, show the form instead
    if let Some(ref form) = state.form {
        return mcp_server_form_view(form, &state.validation_errors);
    }

    // If copy sheet is active, show it
    if let Some(ref sheet) = state.copy_sheet {
        return super::mcp_copy_sheet::copy_sheet_view(sheet, &state.servers);
    }

    // If import sheet is active, show it
    if let Some(ref sheet) = state.import_sheet {
        return super::mcp_copy_sheet::import_sheet_view(sheet);
    }

    // Header with action buttons
    let add_btn = button(text("Add Server").size(12))
        .on_press(Message::MCPAddServer)
        .padding(Padding::new(4.0).left(12.0).right(12.0));

    let export_btn = button(text("Export").size(12))
        .on_press(Message::MCPExportToClipboard)
        .padding(Padding::new(4.0).left(12.0).right(12.0))
        .style(|_theme: &iced::Theme, _status| button::Style {
            background: Some(styles::SELECTED_BG.into()),
            text_color: styles::TEXT_PRIMARY,
            border: iced::Border {
                radius: 4.0.into(),
                ..Default::default()
            },
            shadow: iced::Shadow::default(),
        });

    let import_btn = button(text("Import").size(12))
        .on_press(Message::MCPOpenImportSheet)
        .padding(Padding::new(4.0).left(12.0).right(12.0))
        .style(|_theme: &iced::Theme, _status| button::Style {
            background: Some(styles::SELECTED_BG.into()),
            text_color: styles::TEXT_PRIMARY,
            border: iced::Border {
                radius: 4.0.into(),
                ..Default::default()
            },
            shadow: iced::Shadow::default(),
        });

    let copy_btn = button(text("Copy To...").size(12))
        .on_press(Message::MCPOpenCopySheet)
        .padding(Padding::new(4.0).left(12.0).right(12.0))
        .style(|_theme: &iced::Theme, _status| button::Style {
            background: Some(styles::SELECTED_BG.into()),
            text_color: styles::TEXT_PRIMARY,
            border: iced::Border {
                radius: 4.0.into(),
                ..Default::default()
            },
            shadow: iced::Shadow::default(),
        });

    let actions = row![add_btn, export_btn, import_btn, copy_btn].spacing(8);

    if state.servers.is_empty() {
        return container(
            column![
                text("MCP Servers").size(20).color(styles::TEXT_PRIMARY),
                text("Manage MCP server configurations.")
                    .size(13)
                    .color(styles::TEXT_SECONDARY),
                actions,
                container(
                    text("No MCP servers configured.")
                        .size(14)
                        .color(styles::TEXT_SECONDARY),
                )
                .padding(40)
                .width(Length::Fill)
                .center_x(Length::Fill),
            ]
            .spacing(12),
        )
        .padding(24)
        .width(Length::Fill)
        .height(Length::Fill)
        .into();
    }

    // Server cards
    let mut cards = column![].spacing(8);
    for (name, server) in &state.servers {
        let is_expanded = state.expanded_servers.contains(name);
        cards = cards.push(server_card(name, server, is_expanded));
    }

    container(
        column![
            text("MCP Servers").size(20).color(styles::TEXT_PRIMARY),
            text("Manage MCP server configurations.")
                .size(13)
                .color(styles::TEXT_SECONDARY),
            actions,
            scrollable(cards).height(Length::Fill),
        ]
        .spacing(12),
    )
    .padding(24)
    .width(Length::Fill)
    .height(Length::Fill)
    .into()
}

fn server_card<'a>(name: &str, server: &MCPServer, is_expanded: bool) -> Element<'a, Message> {
    let type_label = if server.is_http() { "http" } else { "stdio" };
    let type_color = if server.is_http() {
        iced::Color::from_rgb(0.3, 0.6, 0.9)
    } else {
        iced::Color::from_rgb(0.3, 0.8, 0.4)
    };

    let type_badge = container(text(type_label).size(10).color(type_color))
        .padding(Padding::new(2.0).left(6.0).right(6.0))
        .style(move |_theme: &iced::Theme| container::Style {
            background: Some(iced::Color::from_rgba(0.0, 0.0, 0.0, 0.3).into()),
            border: iced::Border {
                radius: 3.0.into(),
                ..Default::default()
            },
            ..Default::default()
        });

    let summary = if server.is_http() {
        server.url.as_deref().unwrap_or("(no url)")
    } else {
        server.command.as_deref().unwrap_or("(no command)")
    };

    let name_owned = name.to_string();
    let name_for_edit = name.to_string();
    let name_for_delete = name.to_string();

    let expand_msg = if is_expanded {
        Message::MCPCollapseServer(name_owned.clone())
    } else {
        Message::MCPExpandServer(name_owned)
    };

    let expand_label = if is_expanded { "v" } else { ">" };

    let header_row = row![
        button(text(expand_label).size(11))
            .on_press(expand_msg)
            .padding(Padding::new(2.0).left(4.0).right(4.0))
            .style(|_theme: &iced::Theme, _status| button::Style {
                background: None,
                text_color: styles::TEXT_SECONDARY,
                border: iced::Border::default(),
                shadow: iced::Shadow::default(),
            }),
        type_badge,
        text(name.to_string()).size(14).color(styles::TEXT_PRIMARY),
        text(summary.to_string())
            .size(12)
            .color(styles::TEXT_SECONDARY),
        iced::widget::horizontal_space(),
        button(text("Edit").size(11))
            .on_press(Message::MCPEditServer(name_for_edit))
            .padding(Padding::new(2.0).left(8.0).right(8.0))
            .style(|_theme: &iced::Theme, _status| button::Style {
                background: None,
                text_color: styles::ACCENT,
                border: iced::Border::default(),
                shadow: iced::Shadow::default(),
            }),
        button(text("x").size(11))
            .on_press(Message::MCPDeleteServer(name_for_delete))
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

    let mut card_content = column![header_row].spacing(6);

    if is_expanded {
        // Show args
        if let Some(ref args) = server.args {
            if !args.is_empty() {
                card_content = card_content.push(
                    text(format!("Args: {}", args.join(" ")))
                        .size(12)
                        .color(styles::TEXT_SECONDARY),
                );
            }
        }

        // Show env vars
        if let Some(ref env) = server.env {
            let mut keys: Vec<_> = env.keys().collect();
            keys.sort();
            for key in keys {
                let value = &env[key];
                let display = if is_sensitive_key(key) {
                    "********".to_string()
                } else {
                    value.clone()
                };
                card_content = card_content.push(
                    text(format!("{key}={display}"))
                        .size(11)
                        .color(styles::TEXT_SECONDARY),
                );
            }
        }

        // Show headers for HTTP
        if let Some(ref headers) = server.headers {
            let mut keys: Vec<_> = headers.keys().collect();
            keys.sort();
            for key in keys {
                card_content = card_content.push(
                    text(format!("{key}: ********"))
                        .size(11)
                        .color(styles::TEXT_SECONDARY),
                );
            }
        }
    }

    container(card_content)
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

fn is_sensitive_key(key: &str) -> bool {
    let upper = key.to_uppercase();
    ["TOKEN", "KEY", "SECRET", "PASSWORD"]
        .iter()
        .any(|pat| upper.contains(pat))
}
