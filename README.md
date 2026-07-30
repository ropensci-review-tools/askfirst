# askfirst

> Connect AI with your coding communities

Open source software has always been built on communities. Communities of users; communities of developers; and the communities all around them. Communities actively engage with open-source software by giving feedback, discussing ideas, and reporting bugs. 

But now coding assistants do all the work for us. When your coding assistant finds something my software can't do, it will implement it's own work-around solution. Every person's coding assistant is trained to implement its own solution. Independently. With no feedback towards the original authors of any software.

`askfirst` is intended both for developers and users of software. If an issue could be resolved within software that has `askfirst` functions, anyone using that software through an AI will be advised by their AI to contact the developers.

## askfirst for everybody

To make sure your AI will respond appropriately to `askfirst` messages, install the agent-specific hooks for your project:

**Linux and macOS:**

```bash
curl -fsSL https://raw.githubusercontent.com/ropensci-review-tools/askfirst/main/install.sh | bash
```

**Windows (PowerShell):**

```powershell
irm https://raw.githubusercontent.com/ropensci-review-tools/askfirst/main/install.ps1 | iex
```

**R users:** `askfirst::askfirst_install_agent_hooks("<agent>")` provides the same install as an
R-native alternative — see the
[vignette](bindings/r/vignettes/using-askfirst.Rmd) for details.

## askfirst for developers

As a software developer, you can use `askfirst` to insert simple conditions in your code, like:

- "Scenarios" describing ways your package could be usefully extended.
- "Capability gaps" describing ways that current functions could be extended.
