---
title: Plutonium Modules
---

# Plutonium Modules

Plutonium is built as a collection of focused, interconnected modules that extend Rails with powerful conventions and capabilities. Each module tackles a specific aspect of application development—from managing data and business logic to creating beautiful user interfaces.

This modular design means you can learn and use only what you need, while still benefiting from the seamless integration across the entire framework.

---

## Architecture Modules
The foundational components that structure and organize your Plutonium application.

<div class="grid grid-cols-1 md:grid-cols-2 gap-4">
  <div class="card">
    <a href="./core" class="block p-4">
      <h3 class="font-bold">Core Module</h3>
      <p class="text-sm">The foundation that powers everything—base controllers, essential utilities, and framework integration points.</p>
    </a>
  </div>
  <div class="card">
    <a href="./controller" class="block p-4">
      <h3 class="font-bold">Controller Module</h3>
      <p class="text-sm">Smart HTTP request handling with built-in CRUD operations, authorization, and multi-tenancy support.</p>
    </a>
  </div>
  <div class="card">
    <a href="./routing" class="block p-4">
      <h3 class="font-bold">Routing Module</h3>
      <p class="text-sm">Intelligent resource routing that automatically creates nested routes, handles entity scoping, and manages interactive actions.</p>
    </a>
  </div>
  <div class="card">
    <a href="./package" class="block p-4">
      <h3 class="font-bold">Package Module</h3>
      <p class="text-sm">Organize your application into self-contained, reusable packages using enhanced Rails Engines.</p>
    </a>
  </div>
  <div class="card">
    <a href="./portal" class="block p-4">
      <h3 class="font-bold">Portal Module</h3>
      <p class="text-sm">Create distinct application interfaces for different user types while managing multi-tenancy and access control.</p>
    </a>
  </div>
  <div class="card">
    <a href="./authentication" class="block p-4">
      <h3 class="font-bold">Authentication Module</h3>
      <p class="text-sm">Secure, flexible authentication powered by Rodauth with support for multiple account types and strategies.</p>
    </a>
  </div>
  <div class="card">
    <a href="./configuration" class="block p-4">
      <h3 class="font-bold">Configuration Module</h3>
      <p class="text-sm">Centralized configuration management for customizing every aspect of your Plutonium application.</p>
    </a>
  </div>
</div>

## Business Logic Modules
The tools for defining your application's data structures, business rules, and operations.

<div class="grid grid-cols-1 md:grid-cols-2 gap-4">
  <div class="card">
    <a href="./resource_record" class="block p-4">
      <h3 class="font-bold">Resource Record Module</h3>
      <p class="text-sm">The heart of your application—define models, their behavior, and how they interact with the world.</p>
    </a>
  </div>
  <div class="card">
    <a href="./interaction" class="block p-4">
      <h3 class="font-bold">Interaction Module</h3>
      <p class="text-sm">Encapsulate complex business logic into clean, testable, and reusable service objects.</p>
    </a>
  </div>
  <div class="card">
    <a href="./action" class="block p-4">
      <h3 class="font-bold">Action Module</h3>
      <p class="text-sm">Define custom operations that users can perform on resources, with automatic UI generation and routing.</p>
    </a>
  </div>
  <div class="card">
    <a href="./query" class="block p-4">
      <h3 class="font-bold">Query Module</h3>
      <p class="text-sm">Powerful, declarative data querying with built-in filtering, searching, and sorting capabilities.</p>
    </a>
  </div>
  <div class="card">
    <a href="./policy" class="block p-4">
      <h3 class="font-bold">Policy Module</h3>
      <p class="text-sm">Comprehensive authorization and access control built on the robust Action Policy framework.</p>
    </a>
  </div>
</div>

## User Interface Modules
Everything you need to create beautiful, consistent, and functional user interfaces.

<div class="grid grid-cols-1 md:grid-cols-2 gap-4">
  <div class="card">
    <a href="./ui" class="block p-4">
      <h3 class="font-bold">UI Module</h3>
      <p class="text-sm">The foundation for all UI components, providing core rendering logic and display patterns.</p>
    </a>
  </div>
  <div class="card">
    <a href="./display" class="block p-4">
      <h3 class="font-bold">Display Module</h3>
      <p class="text-sm">Rich components for presenting data in various formats—from simple text to complex visualizations.</p>
    </a>
  </div>
  <div class="card">
    <a href="./form" class="block p-4">
      <h3 class="font-bold">Form Module</h3>
      <p class="text-sm">Powerful form builder with automatic field generation, validation handling, and complex input types.</p>
    </a>
  </div>
  <div class="card">
    <a href="./table" class="block p-4">
      <h3 class="font-bold">Table Module</h3>
      <p class="text-sm">Feature-rich data tables with sorting, filtering, pagination, and bulk operations out of the box.</p>
    </a>
  </div>
</div>

## Development & Tooling Modules
Accelerate your development workflow with powerful generators and utilities.

<div class="grid grid-cols-1 md:grid-cols-2 gap-4">
  <div class="card">
    <a href="./generator" class="block p-4">
      <h3 class="font-bold">Generator Module</h3>
      <p class="text-sm">Comprehensive code generators for scaffolding every component of your Plutonium application.</p>
    </a>
  </div>
  <div class="card">
    <a href="./helper" class="block p-4">
      <h3 class="font-bold">Helper Module</h3>
      <p class="text-sm">A rich collection of view helpers and utilities that simplify template development and UI creation.</p>
    </a>
  </div>
</div>

## Coming Soon
These modules are actively being developed and will be available in future releases.

<div class="grid grid-cols-1 md:grid-cols-2 gap-4">
  <div class="card">
    <div class="p-4">
      <h3 class="font-bold">Testing Module <span class="text-xs font-mono text-gray-400">In Development</span></h3>
      <p class="text-sm">Comprehensive testing utilities and patterns specifically designed for Plutonium applications.</p>
    </div>
  </div>
  <div class="card">
    <div class="p-4">
      <h3 class="font-bold">Asset Module <span class="text-xs font-mono text-gray-400">In Development</span></h3>
      <p class="text-sm">Advanced tools for managing assets, dependencies, and the modern JavaScript/CSS pipeline.</p>
    </div>
  </div>
  <div class="card">
    <div class="p-4">
      <h3 class="font-bold">Theme Module <span class="text-xs font-mono text-gray-400">In Development</span></h3>
      <p class="text-sm">A comprehensive theming system for deep customization of your application's look and feel.</p>
    </div>
  </div>
</div>
