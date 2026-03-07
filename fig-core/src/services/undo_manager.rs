/// Generic undo/redo manager with dirty state tracking.
///
/// Manages a history stack of snapshots with configurable maximum size.
/// Tracks whether the current state differs from the last saved state.
#[derive(Debug, Clone)]
pub struct UndoManager<T: Clone + PartialEq> {
    current: T,
    undo_stack: Vec<T>,
    redo_stack: Vec<T>,
    saved_state: T,
    max_history: usize,
}

impl<T: Clone + PartialEq> UndoManager<T> {
    pub fn new(initial: T, max_history: usize) -> Self {
        Self {
            saved_state: initial.clone(),
            current: initial,
            undo_stack: Vec::new(),
            redo_stack: Vec::new(),
            max_history,
        }
    }

    pub fn current(&self) -> &T {
        &self.current
    }

    pub fn push(&mut self, state: T) {
        self.undo_stack.push(self.current.clone());
        self.current = state;
        self.redo_stack.clear();

        // Enforce max history
        if self.undo_stack.len() > self.max_history {
            let excess = self.undo_stack.len() - self.max_history;
            self.undo_stack.drain(..excess);
        }
    }

    pub fn undo(&mut self) -> Option<&T> {
        let previous = self.undo_stack.pop()?;
        self.redo_stack.push(self.current.clone());
        self.current = previous;
        Some(&self.current)
    }

    pub fn redo(&mut self) -> Option<&T> {
        let next = self.redo_stack.pop()?;
        self.undo_stack.push(self.current.clone());
        self.current = next;
        Some(&self.current)
    }

    pub fn can_undo(&self) -> bool {
        !self.undo_stack.is_empty()
    }

    pub fn can_redo(&self) -> bool {
        !self.redo_stack.is_empty()
    }

    pub fn is_dirty(&self) -> bool {
        self.current != self.saved_state
    }

    pub fn mark_saved(&mut self) {
        self.saved_state = self.current.clone();
    }

    pub fn clear(&mut self) {
        self.undo_stack.clear();
        self.redo_stack.clear();
        self.saved_state = self.current.clone();
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_push_and_undo() {
        let mut mgr = UndoManager::new("a".to_string(), 10);
        mgr.push("b".to_string());
        mgr.push("c".to_string());
        assert_eq!(mgr.current(), "c");

        let result = mgr.undo();
        assert_eq!(result, Some(&"b".to_string()));
        assert_eq!(mgr.current(), "b");

        let result = mgr.undo();
        assert_eq!(result, Some(&"a".to_string()));
        assert_eq!(mgr.current(), "a");
    }

    #[test]
    fn test_redo_after_undo() {
        let mut mgr = UndoManager::new("a".to_string(), 10);
        mgr.push("b".to_string());
        mgr.push("c".to_string());
        mgr.undo();
        mgr.undo();

        let result = mgr.redo();
        assert_eq!(result, Some(&"b".to_string()));

        let result = mgr.redo();
        assert_eq!(result, Some(&"c".to_string()));
    }

    #[test]
    fn test_push_clears_redo() {
        let mut mgr = UndoManager::new("a".to_string(), 10);
        mgr.push("b".to_string());
        mgr.push("c".to_string());
        mgr.undo(); // back to "b"
        assert!(mgr.can_redo());

        mgr.push("d".to_string()); // should clear redo
        assert!(!mgr.can_redo());
    }

    #[test]
    fn test_is_dirty() {
        let mut mgr = UndoManager::new("a".to_string(), 10);
        assert!(!mgr.is_dirty());

        mgr.push("b".to_string());
        assert!(mgr.is_dirty());

        mgr.mark_saved();
        assert!(!mgr.is_dirty());

        mgr.push("c".to_string());
        assert!(mgr.is_dirty());

        mgr.undo(); // back to "b" which is saved
        assert!(!mgr.is_dirty());
    }

    #[test]
    fn test_max_history() {
        let mut mgr = UndoManager::new(0, 3);
        mgr.push(1);
        mgr.push(2);
        mgr.push(3);
        mgr.push(4); // oldest (0) should be dropped

        assert_eq!(mgr.current(), &4);

        // Can only undo 3 times (max_history)
        assert!(mgr.undo().is_some()); // 3
        assert!(mgr.undo().is_some()); // 2
        assert!(mgr.undo().is_some()); // 1
        assert!(mgr.undo().is_none()); // can't go further
    }

    #[test]
    fn test_undo_empty() {
        let mut mgr = UndoManager::new("a".to_string(), 10);
        assert!(!mgr.can_undo());
        assert_eq!(mgr.undo(), None);
    }

    #[test]
    fn test_redo_empty() {
        let mut mgr = UndoManager::new("a".to_string(), 10);
        assert!(!mgr.can_redo());
        assert_eq!(mgr.redo(), None);
    }

    #[test]
    fn test_clear() {
        let mut mgr = UndoManager::new("a".to_string(), 10);
        mgr.push("b".to_string());
        mgr.push("c".to_string());
        mgr.undo();

        assert!(mgr.can_undo());
        assert!(mgr.can_redo());

        mgr.clear();
        assert!(!mgr.can_undo());
        assert!(!mgr.can_redo());
        assert!(!mgr.is_dirty());
        assert_eq!(mgr.current(), "b"); // current preserved
    }

    #[test]
    fn test_multiple_undo_redo() {
        let mut mgr = UndoManager::new(1, 10);
        for i in 2..=5 {
            mgr.push(i);
        }
        assert_eq!(mgr.current(), &5);

        // Undo all
        for expected in (1..=4).rev() {
            let result = mgr.undo().unwrap();
            assert_eq!(*result, expected);
        }
        assert!(!mgr.can_undo());

        // Redo all
        for expected in 2..=5 {
            let result = mgr.redo().unwrap();
            assert_eq!(*result, expected);
        }
        assert!(!mgr.can_redo());
    }
}
