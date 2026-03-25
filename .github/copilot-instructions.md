- [ ] Verify that the copilot-instructions.md file in the .github directory is created.

- [ ] Clarify Project Requirements

- [ ] Scaffold the Project

- [ ] Customize the Project

- [ ] Install Required Extensions

- [ ] Compile the Project

- [ ] Create and Run Task

- [ ] Launch the Project

- [ ] Ensure Documentation is Complete
- Keep progress tracked with the available planning tools.
- After each step, update status and a short summary.
- Avoid verbose explanations or full command dumps.
- Use `.` as the working directory unless the user specifies otherwise.
- Only install extensions explicitly provided by project setup information.
- Keep the README and this file current.
- Treat this repository as potentially running under PowerShell Constrained Language Mode, especially for validation and dry-run workflows.
- Avoid reintroducing non-core runtime constructs in validation or dry-run paths.
- Prefer plain hashtables and arrays over `PSCustomObject`, generic .NET collections, or custom types for runtime state.
- Avoid `New-Object` for non-core types in validation or dry-run code paths.
- Avoid .NET static or instance method calls in validation or dry-run code paths when a PowerShell operator or cmdlet can do the same job.
- Avoid classes and APIs such as `System.Uri`, `System.Guid`, `System.Diagnostics.Stopwatch`, `System.Runtime.InteropServices.RuntimeInformation`, `IntPtr` construction for simulated values, and similar non-core .NET helpers in constrained-mode-safe paths.
- Keep `Add-Type`, UI Automation, Win32 interop, and `System.Windows.Forms.SendKeys` isolated to live Windows automation paths only.
- Work through each checklist item systematically.
- Keep communication concise and focused.
- Follow development best practices.
