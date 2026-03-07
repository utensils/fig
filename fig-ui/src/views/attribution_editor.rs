use fig_core::models::{Attribution, EditingTarget};
use iced::widget::{checkbox, column, container, pick_list, text};
use iced::{Element, Length};

use crate::styles;
use crate::Message;

#[derive(Debug, Clone, PartialEq)]
pub struct AttributionEditorState {
    pub commits_enabled: bool,
    pub pull_requests_enabled: bool,
    pub editing_target: EditingTarget,
}

impl Default for AttributionEditorState {
    fn default() -> Self {
        Self {
            commits_enabled: false,
            pull_requests_enabled: false,
            editing_target: EditingTarget::Global,
        }
    }
}

#[allow(dead_code)]
impl AttributionEditorState {
    pub fn from_attribution(attr: Option<&Attribution>, target: EditingTarget) -> Self {
        match attr {
            Some(a) => Self {
                commits_enabled: a.commits.unwrap_or(false),
                pull_requests_enabled: a.pull_requests.unwrap_or(false),
                editing_target: target,
            },
            None => Self {
                editing_target: target,
                ..Default::default()
            },
        }
    }

    pub fn to_attribution(&self) -> Attribution {
        Attribution {
            commits: Some(self.commits_enabled),
            pull_requests: Some(self.pull_requests_enabled),
            ..Default::default()
        }
    }
}

pub fn attribution_editor_view<'a>(state: &'a AttributionEditorState) -> Element<'a, Message> {
    let target_options: Vec<EditingTarget> = if state.editing_target == EditingTarget::Global {
        vec![EditingTarget::Global]
    } else {
        EditingTarget::project_targets().to_vec()
    };

    let target_picker = pick_list(
        target_options,
        Some(state.editing_target),
        Message::AttributionChangeTarget,
    )
    .text_size(13);

    let commits_toggle = checkbox("Add attribution to commits", state.commits_enabled)
        .on_toggle(Message::AttributionToggleCommits)
        .text_size(14);

    let commits_desc =
        text("When enabled, Claude Code adds a 'Co-authored-by' trailer to commits.")
            .size(12)
            .color(styles::TEXT_SECONDARY);

    let pr_toggle = checkbox(
        "Add attribution to pull requests",
        state.pull_requests_enabled,
    )
    .on_toggle(Message::AttributionTogglePullRequests)
    .text_size(14);

    let pr_desc =
        text("When enabled, Claude Code adds attribution text to pull request descriptions.")
            .size(12)
            .color(styles::TEXT_SECONDARY);

    container(
        column![
            text("Attribution").size(20).color(styles::TEXT_PRIMARY),
            text("Control how Claude Code attributes its contributions.")
                .size(13)
                .color(styles::TEXT_SECONDARY),
            target_picker,
            commits_toggle,
            commits_desc,
            pr_toggle,
            pr_desc,
        ]
        .spacing(12),
    )
    .padding(24)
    .width(Length::Fill)
    .height(Length::Fill)
    .into()
}
