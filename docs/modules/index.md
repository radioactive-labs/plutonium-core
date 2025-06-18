---
title: Plutonium Modules
---

# Plutonium Modules

Plutonium is a collection of modular, interconnected components that extend Rails. Each module is designed to handle a specific aspect of application development, from UI components to business logic and architecture.

This modularity allows you to understand and use only the parts of the framework you need while ensuring a consistent and integrated experience across the entire stack.

---

## Architecture Modules
The foundational pillars of a Plutonium application, managing structure, tenancy, and configuration.

<div class="grid grid-cols-1 md:grid-cols-2 gap-4">
  <div class="card">
    <a href="./core" class="block p-4">
      <h3 class="font-bold">Core Module</h3>
    </a>
      <p class="text-sm">Provides the foundational components, conventions, and boot process for the framework.</p>
  </div>
  <div class="card">
    <a href="./package" class="block p-4">
      <h3 class="font-bold">Package Module</h3>
    </a>
      <p class="text-sm">Enables modular application organization through self-contained packages (Rails Engines).</p>
  </div>
  <div class="card">
    <a href="./portal" class="block p-4">
      <h3 class="font-bold">Portal Module</h3>
    </a>
      <p class="text-sm">Manages application segmentation, multi-tenancy, and isolated user-facing interfaces.</p>
  </div>
  <div class="card">
    <a href="./authentication" class="block p-4">
      <h3 class="font-bold">Authentication Module</h3>
    </a>
      <p class="text-sm">Integrates with Rodauth for secure, multi-account authentication strategies.</p>
  </div>
  <div class="card">
    <a href="./configuration" class="block p-4">
      <h3 class="font-bold">Configuration Module</h3>
    </a>
      <p class="text-sm">Provides a centralized API for configuring all aspects of the framework.</p>
  </div>
</div>

## Business Logic Modules
Modules for defining your application's data, behavior, and rules.

<div class="grid grid-cols-1 md:grid-cols-2 gap-4">
  <div class="card">
    <a href="./resource" class="block p-4">
      <h3 class="font-bold">Resource Module</h3>
    </a>
      <p class="text-sm">The core of data management, defining models, fields, and their behavior.</p>
  </div>
  <div class="card">
    <a href="./interaction" class="block p-4">
      <h3 class="font-bold">Interaction Module</h3>
    </a>
      <p class="text-sm">Encapsulates business logic into clean, reusable, and testable objects.</p>
  </div>
  <div class="card">
    <a href="./action" class="block p-4">
      <h3 class="font-bold">Action Module</h3>
    </a>
      <p class="text-sm">Defines custom operations that can be performed on resources, with automatic UI generation.</p>
  </div>
  <div class="card">
    <a href="./query" class="block p-4">
      <h3 class="font-bold">Query Module</h3>
    </a>
      <p class="text-sm">Manages declarative data querying, filtering, and full-text search.</p>
  </div>
  <div class="card">
    <a href="./policy" class="block p-4">
      <h3 class="font-bold">Policy Module</h3>
    </a>
      <p class="text-sm">Handles authorization and access control, built on the robust Action Policy framework.</p>
  </div>
</div>

## UI Modules
A comprehensive set of components for building beautiful and consistent user interfaces.

<div class="grid grid-cols-1 md:grid-cols-2 gap-4">
  <div class="card">
    <a href="./ui" class="block p-4">
      <h3 class="font-bold">UI Module</h3>
    </a>
      <p class="text-sm">The base module for all UI components, providing core display and rendering logic.</p>
  </div>
  <div class="card">
    <a href="./display" class="block p-4">
      <h3 class="font-bold">Display Module</h3>
    </a>
      <p class="text-sm">A collection of components for presenting data in various formats.</p>
  </div>
  <div class="card">
    <a href="./form" class="block p-4">
      <h3 class="font-bold">Form Module</h3>
    </a>
      <p class="text-sm">Provides a powerful and flexible builder API for creating complex forms.</p>
  </div>
  <div class="card">
    <a href="./table" class="block p-4">
      <h3 class="font-bold">Table Module</h3>
    </a>
      <p class="text-sm">Manages the display of data grids with sorting, filtering, and pagination.</p>
  </div>
</div>

## Development & Tooling Modules
Tools to accelerate development and streamline common tasks.

<div class="grid grid-cols-1 md:grid-cols-2 gap-4">
  <div class="card">
    <a href="./generator" class="block p-4">
      <h3 class="font-bold">Generator Module</h3>
    </a>
      <p class="text-sm">Provides a rich set of code generators for scaffolding every part of a Plutonium application.</p>
  </div>
  <div class="card">
    <a href="./helper" class="block p-4">
      <h3 class="font-bold">Helper Module</h3>
    </a>
      <p class="text-sm">A collection of view helpers and utilities to simplify template development.</p>
  </div>
</div>

## Planned Modules
These modules are on our roadmap and are currently under development.

<div class="grid grid-cols-1 md:grid-cols-2 gap-4">
  <div class="card">
      <div class="p-4">
        <h3 class="font-bold">Testing Module <span class="text-xs font-mono text-gray-400">In Progress</span></h3>
      </div>
        <p class="text-sm">Utilities and patterns for testing Plutonium applications.</p>
  </div>
  <div class="card">
      <div class="p-4">
        <h3 class="font-bold">Asset Module <span class="text-xs font-mono text-gray-400">In Progress</span></h3>
      </div>
        <p class="text-sm">Tools for managing the asset pipeline and external dependencies.</p>
  </div>
  <div class="card">
      <div class="p-4">
        <h3 class="font-bold">Theme Module <span class="text-xs font-mono text-gray-400">In Progress</span></h3>
      </div>
        <p class="text-sm">A comprehensive theming system for deep UI customization.</p>
  </div>
</div>
