use std::collections::HashSet;

use fig_core::models::{ConfigSource, MCPServer};
use fig_core::services::CopyConflict;
use iced::widget::{button, checkbox, column, container, row, scrollable, text, text_input};
use iced::{Element, Length, Padding};

use crate::styles;
use crate::Message;

#[derive(Debug, Clone, PartialEq)]
pub struct CopySheetState {
    pub selected_servers: HashSet<String>,
    pub target_source: ConfigSource,
    pub conflicts: Vec<CopyConflict>,
    pub show_conflicts: bool,
}

impl Default for CopySheetState {
    fn default() -> Self {
        Self {
            selected_servers: HashSet::new(),
            target_source: ConfigSource::Global,
            conflicts: Vec::new(),
            show_conflicts: false,
        }
    }
}

#[derive(Debug, Clone, PartialEq)]
pub struct ImportSheetState {
    pub json_input: String,
    pub parsed_servers: Vec<(String, MCPServer)>,
    pub selected_servers: HashSet<String>,
    pub parse_error: Option<String>,
    pub redact_on_export: bool,
}

impl Default for ImportSheetState {
    fn default() -> Self {
        Self {
            json_input: String::new(),
            parsed_servers: Vec::new(),
            selected_servers: HashSet::new(),
            parse_error: None,
            redact_on_export: true,
        }
    }
}

pub fn copy_sheet_view<'a>(
    state: &'a CopySheetState,
    servers: &'a [(String, MCPServer)],
) -> Element<'a, Message> {
    let mut content = column![
        text("Copy Servers").size(20).color(styles::TEXT_PRIMARY),
        text("Select servers to copy to another scope.")
            .size(13)
            .color(styles::TEXT_SECONDARY),
    ]
    .spacing(8);

    // Target scope picker
    let target_options = vec![
        ConfigSource::Global,
        ConfigSource::ProjectShared,
        ConfigSource::ProjectLocal,
    ];
    content = content
        .push(text("Target Scope").size(12).color(styles::TEXT_SECONDARY))
        .push(
            iced::widget::pick_list(
                target_options,
                Some(state.target_source),
                Message::MCPCopySelectTarget,
            )
            .text_size(13),
        );

    // Server checkboxes
    let mut server_list = column![].spacing(4);
    for (name, server) in servers {
        let is_selected = state.selected_servers.contains(name);
        let summary = if server.is_http() {
            server.url.as_deref().unwrap_or("(no url)")
        } else {
            server.command.as_deref().unwrap_or("(no command)")
        };
        let label = format!("{name} ({summary})");
        let name_owned = name.clone();
        server_list = server_list.push(
            checkbox(label, is_selected)
                .on_toggle(move |_| Message::MCPCopyToggleServer(name_owned.clone()))
                .text_size(13),
        );
    }
    content = content.push(scrollable(server_list).height(200));

    // Conflicts display
    if state.show_conflicts && !state.conflicts.is_empty() {
        let mut conflict_col = column![text("Conflicts detected:")
            .size(13)
            .color(iced::Color::from_rgb(0.9, 0.6, 0.2)),]
        .spacing(4);
        for conflict in &state.conflicts {
            conflict_col = conflict_col.push(
                text(format!(
                    "  {} already exists ({})",
                    conflict.server_name, conflict.existing_summary
                ))
                .size(12)
                .color(styles::TEXT_SECONDARY),
            );
        }
        conflict_col = conflict_col.push(
            button(text("Force Overwrite").size(12))
                .on_press(Message::MCPCopyForceOverwrite)
                .padding(Padding::new(4.0).left(12.0).right(12.0)),
        );
        content = content.push(conflict_col);
    }

    // Buttons
    let confirm_btn = button(text("Copy").size(13))
        .on_press(Message::MCPCopyConfirm)
        .padding(Padding::new(6.0).left(16.0).right(16.0));
    let cancel_btn = button(text("Cancel").size(13))
        .on_press(Message::MCPCloseCopySheet)
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

    content = content.push(row![confirm_btn, cancel_btn].spacing(8));

    container(content)
        .padding(24)
        .width(Length::Fill)
        .height(Length::Fill)
        .into()
}

pub fn import_sheet_view<'a>(state: &'a ImportSheetState) -> Element<'a, Message> {
    let mut content = column![
        text("Import Servers").size(20).color(styles::TEXT_PRIMARY),
        text("Paste MCP server JSON configuration to import.")
            .size(13)
            .color(styles::TEXT_SECONDARY),
    ]
    .spacing(8);

    // JSON input
    content = content.push(
        text_input("Paste JSON here...", &state.json_input)
            .on_input(Message::MCPImportPasteJson)
            .size(13)
            .width(Length::Fill),
    );

    // Parse error
    if let Some(ref err) = state.parse_error {
        content = content.push(
            text(err.clone())
                .size(12)
                .color(iced::Color::from_rgb(0.9, 0.3, 0.3)),
        );
    }

    // Parsed servers preview
    if !state.parsed_servers.is_empty() {
        let mut preview = column![text("Servers found:")
            .size(12)
            .color(styles::TEXT_SECONDARY),]
        .spacing(4);
        for (name, server) in &state.parsed_servers {
            let is_selected = state.selected_servers.contains(name);
            let summary = if server.is_http() {
                format!("http: {}", server.url.as_deref().unwrap_or("?"))
            } else {
                format!("stdio: {}", server.command.as_deref().unwrap_or("?"))
            };
            let label = format!("{name} ({summary})");
            let name_owned = name.clone();
            preview = preview.push(
                checkbox(label, is_selected)
                    .on_toggle(move |_| Message::MCPImportToggleServer(name_owned.clone()))
                    .text_size(13),
            );
        }
        content = content.push(preview);
    }

    // Redaction toggle
    content = content.push(
        checkbox("Redact sensitive values on export", state.redact_on_export)
            .on_toggle(Message::MCPToggleRedaction)
            .text_size(12),
    );

    // Buttons
    let import_btn = button(text("Import Selected").size(13))
        .on_press(Message::MCPImportConfirm)
        .padding(Padding::new(6.0).left(16.0).right(16.0));
    let cancel_btn = button(text("Cancel").size(13))
        .on_press(Message::MCPCloseImportSheet)
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

    content = content.push(row![import_btn, cancel_btn].spacing(8));

    container(content)
        .padding(24)
        .width(Length::Fill)
        .height(Length::Fill)
        .into()
}
