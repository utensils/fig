use fig_core::services::{Finding, FindingSeverity};
use iced::widget::{button, column, container, row, scrollable, text};
use iced::{Color, Element, Length, Padding};

use crate::styles;
use crate::Message;

#[derive(Debug, Clone, PartialEq, Default)]
pub struct HealthCheckViewState {
    pub findings: Vec<Finding>,
    pub is_running: bool,
}

#[derive(Debug, Clone, PartialEq, Default)]
#[allow(dead_code)]
pub enum MCPHealthButtonState {
    #[default]
    Idle,
    Checking,
    Success(String),
    Failure(String),
    Timeout,
}

pub fn severity_color(severity: &FindingSeverity) -> Color {
    match severity {
        FindingSeverity::Good => Color::from_rgb(0.3, 0.8, 0.4),
        FindingSeverity::Suggestion => Color::from_rgb(0.4, 0.6, 1.0),
        FindingSeverity::Warning => Color::from_rgb(0.9, 0.7, 0.2),
        FindingSeverity::Security => Color::from_rgb(0.9, 0.3, 0.3),
    }
}

pub fn health_check_view<'a>(state: &'a HealthCheckViewState) -> Element<'a, Message> {
    let run_label = if state.is_running {
        "Running..."
    } else {
        "Run Health Check"
    };

    let mut run_btn =
        button(text(run_label).size(13)).padding(Padding::new(6.0).left(16.0).right(16.0));
    if !state.is_running {
        run_btn = run_btn.on_press(Message::HealthCheckRun);
    }

    let mut content = column![
        text("Health Check").size(20).color(styles::TEXT_PRIMARY),
        text("Analyze your configuration for security issues and best practices.")
            .size(13)
            .color(styles::TEXT_SECONDARY),
        run_btn,
    ]
    .spacing(12);

    if !state.findings.is_empty() {
        // Summary counts
        let security_count = state
            .findings
            .iter()
            .filter(|f| f.severity == FindingSeverity::Security)
            .count();
        let warning_count = state
            .findings
            .iter()
            .filter(|f| f.severity == FindingSeverity::Warning)
            .count();
        let suggestion_count = state
            .findings
            .iter()
            .filter(|f| f.severity == FindingSeverity::Suggestion)
            .count();
        let good_count = state
            .findings
            .iter()
            .filter(|f| f.severity == FindingSeverity::Good)
            .count();

        let summary = row![
            text(format!("{security_count} Security"))
                .size(12)
                .color(severity_color(&FindingSeverity::Security)),
            text(format!("{warning_count} Warning"))
                .size(12)
                .color(severity_color(&FindingSeverity::Warning)),
            text(format!("{suggestion_count} Suggestion"))
                .size(12)
                .color(severity_color(&FindingSeverity::Suggestion)),
            text(format!("{good_count} Good"))
                .size(12)
                .color(severity_color(&FindingSeverity::Good)),
        ]
        .spacing(16);

        content = content.push(summary);

        // Findings list
        let mut findings_col = column![].spacing(6);
        for finding in &state.findings {
            findings_col = findings_col.push(finding_card(finding));
        }

        content = content.push(scrollable(findings_col).height(Length::Fill));
    } else if !state.is_running {
        content = content.push(
            container(
                text("Run a health check to analyze your configuration.")
                    .size(13)
                    .color(styles::TEXT_SECONDARY),
            )
            .padding(20)
            .width(Length::Fill)
            .center_x(Length::Fill),
        );
    }

    container(content)
        .padding(24)
        .width(Length::Fill)
        .height(Length::Fill)
        .into()
}

fn finding_card<'a>(finding: &'a Finding) -> Element<'a, Message> {
    let color = severity_color(&finding.severity);

    let severity_badge = container(text(finding.severity.label()).size(10).color(color))
        .padding(Padding::new(2.0).left(6.0).right(6.0))
        .style(move |_theme: &iced::Theme| container::Style {
            background: Some(Color::from_rgba(0.0, 0.0, 0.0, 0.3).into()),
            border: iced::Border {
                radius: 3.0.into(),
                ..Default::default()
            },
            ..Default::default()
        });

    let check_badge = text(format!("[{}]", finding.check_name))
        .size(10)
        .color(styles::TEXT_SECONDARY);

    container(
        column![
            row![
                severity_badge,
                text(&finding.title).size(13).color(styles::TEXT_PRIMARY),
                iced::widget::horizontal_space(),
                check_badge,
            ]
            .spacing(8)
            .align_y(iced::Alignment::Center),
            text(&finding.description)
                .size(12)
                .color(styles::TEXT_SECONDARY),
        ]
        .spacing(4),
    )
    .padding(Padding::new(8.0).left(12.0).right(12.0))
    .width(Length::Fill)
    .style(|_theme: &iced::Theme| container::Style {
        background: Some(styles::SELECTED_BG.into()),
        border: iced::Border {
            radius: 4.0.into(),
            ..Default::default()
        },
        ..Default::default()
    })
    .into()
}

#[allow(dead_code)]
pub fn mcp_health_button<'a>(name: &str, state: &MCPHealthButtonState) -> Element<'a, Message> {
    let name_owned = name.to_string();
    match state {
        MCPHealthButtonState::Idle => button(text("Check").size(10))
            .on_press(Message::MCPHealthCheck(name_owned))
            .padding(Padding::new(2.0).left(6.0).right(6.0))
            .style(|_theme: &iced::Theme, _status| button::Style {
                background: None,
                text_color: styles::ACCENT,
                border: iced::Border {
                    radius: 3.0.into(),
                    color: styles::ACCENT,
                    width: 1.0,
                },
                shadow: iced::Shadow::default(),
            })
            .into(),
        MCPHealthButtonState::Checking => text("...").size(11).color(styles::TEXT_SECONDARY).into(),
        MCPHealthButtonState::Success(info) => text(format!("OK ({info})"))
            .size(11)
            .color(Color::from_rgb(0.3, 0.8, 0.4))
            .into(),
        MCPHealthButtonState::Failure(err) => text(format!("Err: {err}"))
            .size(11)
            .color(Color::from_rgb(0.9, 0.3, 0.3))
            .into(),
        MCPHealthButtonState::Timeout => text("Timeout")
            .size(11)
            .color(Color::from_rgb(0.9, 0.7, 0.2))
            .into(),
    }
}
