use iced::widget::{center, text};
use iced::{Element, Theme};

fn main() -> iced::Result {
    iced::application("Fig", App::update, App::view)
        .theme(|_| Theme::Dark)
        .run()
}

#[derive(Default)]
struct App;

#[derive(Debug, Clone)]
enum Message {}

impl App {
    fn update(&mut self, _message: Message) {}

    fn view(&self) -> Element<'_, Message> {
        center(text("Fig").size(24)).into()
    }
}
