# SylPolkit

> **Experimental.** Test it on your machine before you depend on it, and keep another way to authorize at hand.

When an app asks for extra rights, SylPolkit shows a Sylvaris password prompt with what is being asked and why. Only one polkit agent can run, so stop hyprpolkitagent or polkit-gnome for it to take over.

`sylvaris polkit preview` shows a sample request; the password `right` completes it.

Polkit asks SylPolkit only when an action needs a password. Actions your polkit rules allow outright, like a rule that returns `polkit.Result.YES` for `org.freedesktop.policykit.exec`, run without a prompt, so `pkexec` can finish silently. To try a real request without running anything, pick an action that `pkaction --verbose` lists with `auth_admin` and run `pkcheck --action-id ACTION --process $$ -u`.
