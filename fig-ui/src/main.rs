mod styles;
mod views;

use fig_core::models::{
    ConfigSource, DiscoveredProject, EditingTarget, GlobalSettingsTab, MCPServerFormData,
    MCPServerType, NavigationSelection, PermissionType, ProjectDetailTab,
};
use fig_core::services::mcp_clipboard_service;
use iced::widget::{container, row};
use iced::{Element, Length, Theme};
use uuid::Uuid;
use views::attribution_editor::AttributionEditorState;
use views::environment_editor::EnvironmentEditorState;
use views::mcp_copy_sheet::{CopySheetState, ImportSheetState};
use views::mcp_server_list::MCPServerListState;
use views::permissions_editor::PermissionsEditorState;

fn main() -> iced::Result {
    iced::application("Fig", App::update, App::view)
        .theme(|_| Theme::Dark)
        .window_size((1000.0, 700.0))
        .run()
}

struct App {
    selection: NavigationSelection,
    global_tab: GlobalSettingsTab,
    project_tab: ProjectDetailTab,
    projects: Vec<DiscoveredProject>,
    group_by_directory: bool,
    permissions_state: PermissionsEditorState,
    environment_state: EnvironmentEditorState,
    attribution_state: AttributionEditorState,
    mcp_list_state: MCPServerListState,
}

#[derive(Debug, Clone)]
pub enum Message {
    // Navigation
    SelectGlobalSettings,
    SelectProject(String),
    SelectGlobalTab(GlobalSettingsTab),
    SelectProjectTab(ProjectDetailTab),

    // Permissions editor
    PermissionsChangeTarget(EditingTarget),
    PermissionsApplyPreset(String),
    PermissionsToggleType,
    PermissionsNewRuleInput(String),
    PermissionsAddRule,
    PermissionsRemoveRule(Uuid),

    // Environment editor
    EnvChangeTarget(EditingTarget),
    EnvNewKeyInput(String),
    EnvNewValueInput(String),
    EnvAddVariable,
    EnvAddKnown(String),
    EnvRemoveVariable(Uuid),

    // Attribution editor
    AttributionChangeTarget(EditingTarget),
    AttributionToggleCommits(bool),
    AttributionTogglePullRequests(bool),

    // MCP Server List
    MCPExpandServer(String),
    MCPCollapseServer(String),
    MCPAddServer,
    MCPEditServer(String),
    MCPDeleteServer(String),

    // MCP Server Form
    MCPFormUpdateName(String),
    MCPFormUpdateCommand(String),
    MCPFormUpdateArgs(String),
    MCPFormUpdateEnv(String),
    MCPFormUpdateUrl(String),
    MCPFormChangeType(MCPServerType),
    MCPFormSave,
    MCPFormCancel,

    // MCP Copy/Paste
    MCPOpenCopySheet,
    MCPCloseCopySheet,
    MCPCopyToggleServer(String),
    MCPCopySelectTarget(ConfigSource),
    MCPCopyConfirm,
    MCPCopyForceOverwrite,
    MCPOpenImportSheet,
    MCPCloseImportSheet,
    MCPImportPasteJson(String),
    MCPImportToggleServer(String),
    MCPImportConfirm,
    MCPExportToClipboard,
    MCPToggleRedaction(bool),
}

impl Default for App {
    fn default() -> Self {
        Self {
            selection: NavigationSelection::GlobalSettings,
            global_tab: GlobalSettingsTab::Permissions,
            project_tab: ProjectDetailTab::Permissions,
            projects: Vec::new(),
            group_by_directory: true,
            permissions_state: PermissionsEditorState::default(),
            environment_state: EnvironmentEditorState::default(),
            attribution_state: AttributionEditorState::default(),
            mcp_list_state: MCPServerListState::default(),
        }
    }
}

impl App {
    fn update(&mut self, message: Message) {
        match message {
            // Navigation
            Message::SelectGlobalSettings => {
                self.selection = NavigationSelection::GlobalSettings;
            }
            Message::SelectProject(path) => {
                self.selection = NavigationSelection::Project(path);
                self.project_tab = ProjectDetailTab::Permissions;
            }
            Message::SelectGlobalTab(tab) => {
                self.global_tab = tab;
            }
            Message::SelectProjectTab(tab) => {
                self.project_tab = tab;
            }

            // Permissions
            Message::PermissionsChangeTarget(target) => {
                self.permissions_state.editing_target = target;
            }
            Message::PermissionsApplyPreset(id) => {
                self.permissions_state.apply_preset(&id);
            }
            Message::PermissionsToggleType => {
                self.permissions_state.new_rule_type = match self.permissions_state.new_rule_type {
                    PermissionType::Allow => PermissionType::Deny,
                    PermissionType::Deny => PermissionType::Allow,
                };
            }
            Message::PermissionsNewRuleInput(text) => {
                self.permissions_state.new_rule_text = text;
            }
            Message::PermissionsAddRule => {
                self.permissions_state.add_rule();
            }
            Message::PermissionsRemoveRule(id) => {
                self.permissions_state.remove_rule(id);
            }

            // Environment
            Message::EnvChangeTarget(target) => {
                self.environment_state.editing_target = target;
            }
            Message::EnvNewKeyInput(key) => {
                self.environment_state.new_key = key;
            }
            Message::EnvNewValueInput(value) => {
                self.environment_state.new_value = value;
            }
            Message::EnvAddVariable => {
                self.environment_state.add_variable();
            }
            Message::EnvAddKnown(name) => {
                self.environment_state.add_known_variable(&name);
            }
            Message::EnvRemoveVariable(id) => {
                self.environment_state.remove_variable(id);
            }

            // Attribution
            Message::AttributionChangeTarget(target) => {
                self.attribution_state.editing_target = target;
            }
            Message::AttributionToggleCommits(enabled) => {
                self.attribution_state.commits_enabled = enabled;
            }
            Message::AttributionTogglePullRequests(enabled) => {
                self.attribution_state.pull_requests_enabled = enabled;
            }

            // MCP Server List
            Message::MCPExpandServer(name) => {
                self.mcp_list_state.expanded_servers.insert(name);
            }
            Message::MCPCollapseServer(name) => {
                self.mcp_list_state.expanded_servers.remove(&name);
            }
            Message::MCPAddServer => {
                self.mcp_list_state.form = Some(MCPServerFormData::new());
                self.mcp_list_state.validation_errors.clear();
            }
            Message::MCPEditServer(name) => {
                if let Some((_, server)) =
                    self.mcp_list_state.servers.iter().find(|(n, _)| n == &name)
                {
                    self.mcp_list_state.form =
                        Some(MCPServerFormData::from_mcp_server(&name, server));
                    self.mcp_list_state.validation_errors.clear();
                }
            }
            Message::MCPDeleteServer(name) => {
                self.mcp_list_state.servers.retain(|(n, _)| n != &name);
            }

            // MCP Server Form
            Message::MCPFormUpdateName(name) => {
                if let Some(ref mut form) = self.mcp_list_state.form {
                    form.name = name;
                }
            }
            Message::MCPFormUpdateCommand(cmd) => {
                if let Some(ref mut form) = self.mcp_list_state.form {
                    form.command = cmd;
                }
            }
            Message::MCPFormUpdateArgs(args) => {
                if let Some(ref mut form) = self.mcp_list_state.form {
                    form.args_text = args;
                }
            }
            Message::MCPFormUpdateEnv(env) => {
                if let Some(ref mut form) = self.mcp_list_state.form {
                    form.env_text = env;
                }
            }
            Message::MCPFormUpdateUrl(url) => {
                if let Some(ref mut form) = self.mcp_list_state.form {
                    form.url = url;
                }
            }
            Message::MCPFormChangeType(server_type) => {
                if let Some(ref mut form) = self.mcp_list_state.form {
                    form.server_type = server_type;
                }
            }
            Message::MCPFormSave => {
                if let Some(ref form) = self.mcp_list_state.form {
                    let errors = form.validate();
                    if errors.is_empty() {
                        let server = form.to_mcp_server();
                        let name = form.name.trim().to_string();

                        // Remove old entry if editing with renamed server
                        if let Some(ref original) = form.original_name {
                            self.mcp_list_state.servers.retain(|(n, _)| n != original);
                        }

                        // Remove existing with same name and re-add
                        self.mcp_list_state.servers.retain(|(n, _)| n != &name);
                        self.mcp_list_state.servers.push((name, server));
                        self.mcp_list_state
                            .servers
                            .sort_by(|(a, _), (b, _)| a.cmp(b));
                        self.mcp_list_state.form = None;
                        self.mcp_list_state.validation_errors.clear();
                    } else {
                        self.mcp_list_state.validation_errors = errors;
                    }
                }
            }
            Message::MCPFormCancel => {
                self.mcp_list_state.form = None;
                self.mcp_list_state.validation_errors.clear();
            }

            // MCP Copy Sheet
            Message::MCPOpenCopySheet => {
                self.mcp_list_state.copy_sheet = Some(CopySheetState::default());
            }
            Message::MCPCloseCopySheet => {
                self.mcp_list_state.copy_sheet = None;
            }
            Message::MCPCopyToggleServer(name) => {
                if let Some(ref mut sheet) = self.mcp_list_state.copy_sheet {
                    if !sheet.selected_servers.remove(&name) {
                        sheet.selected_servers.insert(name);
                    }
                }
            }
            Message::MCPCopySelectTarget(source) => {
                if let Some(ref mut sheet) = self.mcp_list_state.copy_sheet {
                    sheet.target_source = source;
                }
            }
            Message::MCPCopyConfirm | Message::MCPCopyForceOverwrite => {
                // In a full implementation this would call MCPCopyService and
                // write to disk via ConfigFileManager. For now, close the sheet.
                self.mcp_list_state.copy_sheet = None;
            }

            // MCP Import Sheet
            Message::MCPOpenImportSheet => {
                self.mcp_list_state.import_sheet = Some(ImportSheetState::default());
            }
            Message::MCPCloseImportSheet => {
                self.mcp_list_state.import_sheet = None;
            }
            Message::MCPImportPasteJson(json) => {
                if let Some(ref mut sheet) = self.mcp_list_state.import_sheet {
                    sheet.json_input = json.clone();
                    match mcp_clipboard_service::import_from_json(&json) {
                        Ok(servers) => {
                            sheet.selected_servers =
                                servers.iter().map(|(n, _)| n.clone()).collect();
                            sheet.parsed_servers = servers;
                            sheet.parse_error = None;
                        }
                        Err(e) => {
                            sheet.parsed_servers.clear();
                            sheet.selected_servers.clear();
                            if !json.trim().is_empty() {
                                sheet.parse_error = Some(format!("{e}"));
                            } else {
                                sheet.parse_error = None;
                            }
                        }
                    }
                }
            }
            Message::MCPImportToggleServer(name) => {
                if let Some(ref mut sheet) = self.mcp_list_state.import_sheet {
                    if !sheet.selected_servers.remove(&name) {
                        sheet.selected_servers.insert(name);
                    }
                }
            }
            Message::MCPImportConfirm => {
                if let Some(ref sheet) = self.mcp_list_state.import_sheet {
                    for (name, server) in &sheet.parsed_servers {
                        if sheet.selected_servers.contains(name) {
                            self.mcp_list_state.servers.retain(|(n, _)| n != name);
                            self.mcp_list_state
                                .servers
                                .push((name.clone(), server.clone()));
                        }
                    }
                    self.mcp_list_state
                        .servers
                        .sort_by(|(a, _), (b, _)| a.cmp(b));
                }
                self.mcp_list_state.import_sheet = None;
            }
            Message::MCPExportToClipboard => {
                let servers: Vec<(&str, &fig_core::models::MCPServer)> = self
                    .mcp_list_state
                    .servers
                    .iter()
                    .map(|(n, s)| (n.as_str(), s))
                    .collect();
                let _json = mcp_clipboard_service::export_to_json(&servers, false);
                // In a full implementation, this would copy to system clipboard
            }
            Message::MCPToggleRedaction(enabled) => {
                if let Some(ref mut sheet) = self.mcp_list_state.import_sheet {
                    sheet.redact_on_export = enabled;
                }
            }
        }
    }

    fn view(&self) -> Element<'_, Message> {
        let sidebar =
            views::sidebar::sidebar_view(&self.projects, &self.selection, self.group_by_directory);

        let detail = views::detail::detail_view(
            &self.selection,
            self.global_tab,
            self.project_tab,
            &self.permissions_state,
            &self.environment_state,
            &self.attribution_state,
            &self.mcp_list_state,
        );

        let content = row![sidebar, detail]
            .width(Length::Fill)
            .height(Length::Fill);

        container(content)
            .width(Length::Fill)
            .height(Length::Fill)
            .into()
    }
}
