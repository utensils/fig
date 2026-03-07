mod styles;
mod views;

use fig_core::models::{
    DiscoveredProject, EditingTarget, GlobalSettingsTab, NavigationSelection, PermissionType,
    ProjectDetailTab,
};
use iced::widget::{container, row};
use iced::{Element, Length, Theme};
use uuid::Uuid;
use views::attribution_editor::AttributionEditorState;
use views::environment_editor::EnvironmentEditorState;
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
