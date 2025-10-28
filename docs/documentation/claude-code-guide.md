---
title: Claude Code Guide for Plutonium Development
---

<script setup>
import { withBase } from 'vitepress'
</script>

# Claude Code Guide for Plutonium Development

This page provides comprehensive development guidance for building Plutonium applications effectively. This guide is designed to help AI assistants and developers understand the framework's patterns and best practices.

## Quick Start

**Download the CLAUDE.md File**: <a :href="withBase('/CLAUDE.md')" target="_blank">📄 CLAUDE.md</a>

**Or download directly from your terminal**:

::: code-group

```bash [Unix/Linux/macOS/WSL]
curl -o CLAUDE.md https://radioactive-labs.github.io/plutonium-core/CLAUDE.md
```

```cmd [Windows]
curl -o CLAUDE.md https://radioactive-labs.github.io/plutonium-core/CLAUDE.md
```

:::

## Using This Guide

Claude Code uses CLAUDE.md files for project-specific context:

1. **Download the guide**: Right-click the link above and "Save As" to download the `CLAUDE.md` file
2. **Place in your project root** as `CLAUDE.md`
3. **Claude Code automatically loads** this file for project context
4. **Enhance with your own instructions** by adding project-specific details

The guide provides comprehensive patterns and examples for building Plutonium applications with AI assistance.

## What's Included

The CLAUDE.md guide contains comprehensive guidelines for:

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
