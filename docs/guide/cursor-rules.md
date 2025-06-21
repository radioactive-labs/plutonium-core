---
title: Cursor Rules for Plutonium Development
---

<script setup>
import { withBase } from 'vitepress'
</script>

# Cursor Rules for Plutonium Development

This page provides comprehensive cursor rules for building Plutonium applications effectively. These rules are designed to help AI assistants and developers understand the framework's patterns and best practices.

## Quick Start

**Download the Rules File**: <a :href="withBase('/plutonium.mdc')" target="_blank">📄 plutonium.mdc</a>

**Or download directly from your terminal**:

::: code-group

```bash [Unix/Linux/macOS/WSL]
mkdir -p .cursor/rules && curl -o .cursor/rules/plutonium.mdc https://radioactive-labs.github.io/plutonium-core/plutonium.mdc
```

```cmd [Windows]
mkdir .cursor\rules 2>nul & curl -o .cursor\rules\plutonium.mdc https://radioactive-labs.github.io/plutonium-core/plutonium.mdc
```

:::

## Using These Rules

Cursor uses Project Rules stored in `.cursor/rules/` directory:

1. **Download the rules file**: Right-click the link above and "Save As" to download the `.plutonium.mdc` file
2. **Open Cursor Settings** → Rules → Project Rules
3. **Click "Add new rule"** and give it a name (e.g., "plutonium")
4. **Copy the downloaded content** into the new rule file
5. The rule will be saved as `.cursor/rules/plutonium.mdc`

**Legacy Method**: You can also place the downloaded `.plutonium.mdc` file in your project root, but this method is deprecated.

## What's Included

The cursor rules file contains comprehensive guidelines for:

### 🏗️ **Framework Architecture**
- Resource-oriented development patterns
- Package architecture (Feature & Portal packages)
- Component-based UI with Phlex
- Business logic through Interactions

### 📝 **Resource Development**
- **Auto-detection philosophy** - Field types are automatically detected from models
- **Definition patterns** - Only override when needed
- **Policy-based authorization** - Fine-grained permissions
- **Interaction-driven business logic** - Encapsulated operations

### 🔧 **Development Patterns**
- **Generator commands** for scaffolding
- **Authentication setup** with Rodauth
- **Multi-tenancy** with entity scoping
- **Query objects** for filtering and search

### 🎨 **UI Customization**
- **Component architecture** with Phlex
- **Custom display blocks** with `phlexi_tag`
- **Conditional rendering** with context awareness
- **Layout customization** patterns

### ⚡ **Best Practices**
- **Performance optimization** techniques
- **Security guidelines** and defaults
- **Code organization** principles
- **Development workflow** recommendations
