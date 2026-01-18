# Core Concepts

This section explains the fundamental concepts behind Plutonium's architecture.

## Overview

Plutonium is built around a few key principles:

1. **Separation of Concerns** - Each layer has a single responsibility
2. **Convention over Configuration** - Smart defaults, override when needed
3. **Modularity** - Features organized into independent packages
4. **Full Customization** - Every layer can be overridden

## Key Concepts

### [Architecture](./architecture)
How the Model → Definition → Policy → Controller layers work together to create a resource.

### [Resources](./resources)
What resources are and how they differ from plain Rails models.

### [Packages and Portals](./packages-portals)
How to organize your application using Feature Packages and Portal Packages.

### [Auto-Detection](./auto-detection)
How Plutonium automatically discovers fields, associations, and validations.

## The Big Picture

```
┌─────────────────────────────────────────────────────────────┐
│                         PORTAL                               │
│  (Web Interface - routes, authentication, UI customization)  │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                       CONTROLLER                             │
│  (HTTP handling - request/response, rendering)               │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                        POLICY                                │
│  (Authorization - who can do what)                           │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                      DEFINITION                              │
│  (Presentation - how resources render)                       │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                        MODEL                                 │
│  (Data - structure, validations, business rules)             │
└─────────────────────────────────────────────────────────────┘
```

Each layer builds on the one below it, and each can be customized independently.
