/**
 * Applies a check-off and returns the state it ended in.
 *
 * Newer apps say which state they want (`desired`), which makes the request safe to repeat: a retry
 * after a dropped connection, or two phones tapping the same item, can't flip it back. An app that
 * predates this sends nothing, and the item is flipped as it always was.
 */
export async function applyCompletion(
  desired: boolean | undefined,
  actions: {
    isDone: () => Promise<boolean>;
    mark: () => Promise<void>;
    unmark: () => Promise<void>;
  },
) {
  const target = desired ?? !(await actions.isDone());
  if (target) {
    await actions.mark();
  } else {
    await actions.unmark();
  }
  return target;
}
