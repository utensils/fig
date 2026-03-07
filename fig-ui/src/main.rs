mod styles;
mod views;

use fig_core::models::{
    DiscoveredProject, GlobalSettingsTab, NavigationSelection, ProjectDetailTab,
};
use iced::widget::{container, row};
use iced::{Element, Length, Theme};

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
}

#[derive(Debug, Clone)]
pub enum Message {
    SelectGlobalSettings,
    SelectProject(String),
    SelectGlobalTab(GlobalSettingsTab),
    SelectProjectTab(ProjectDetailTab),
}

impl Default for App {
    fn default() -> Self {
        Self {
            selection: NavigationSelection::GlobalSettings,
            global_tab: GlobalSettingsTab::Permissions,
            project_tab: ProjectDetailTab::Permissions,
            projects: Vec::new(),
            group_by_directory: true,
        }
    }
}

impl App {
    fn update(&mut self, message: Message) {
        match message {
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
        }
    }

    fn view(&self) -> Element<'_, Message> {
        let sidebar =
            views::sidebar::sidebar_view(&self.projects, &self.selection, self.group_by_directory);

        let detail = views::detail::detail_view(&self.selection, self.global_tab, self.project_tab);

        let content = row![sidebar, detail]
            .width(Length::Fill)
            .height(Length::Fill);

        container(content)
            .width(Length::Fill)
            .height(Length::Fill)
            .into()
    }
}
