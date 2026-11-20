# Install into abap-copilot-kit

Preferred repository-local layout:

- `.github/agents/auto-abap-delivery.agent.md`
- `.github/skills/auto-abap-delivery/`
- `config/auto-abap-delivery/`
- `docs/auto-abap-delivery/IDEA-V8.md`

If the repository uses user-profile deployment instead, copy the same files to `~/.copilot/agents` and `~/.copilot/skills`. Start a new chat session after installation.

Compatibility rule: do not delegate write operations to existing read-only agents. Use reverse-engineer/tester/dump agents for bounded read-only packets and keep SAP writes in the Delivery Lead after qualification and approval.
