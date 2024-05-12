(() => {
  var __create = Object.create;
  var __defProp = Object.defineProperty;
  var __getOwnPropDesc = Object.getOwnPropertyDescriptor;
  var __getOwnPropNames = Object.getOwnPropertyNames;
  var __getProtoOf = Object.getPrototypeOf;
  var __hasOwnProp = Object.prototype.hasOwnProperty;
  var __commonJS = (cb, mod) => function __require() {
    return mod || (0, cb[__getOwnPropNames(cb)[0]])((mod = { exports: {} }).exports, mod), mod.exports;
  };
  var __copyProps = (to, from, except, desc) => {
    if (from && typeof from === "object" || typeof from === "function") {
      for (let key of __getOwnPropNames(from))
        if (!__hasOwnProp.call(to, key) && key !== except)
          __defProp(to, key, { get: () => from[key], enumerable: !(desc = __getOwnPropDesc(from, key)) || desc.enumerable });
    }
    return to;
  };
  var __toESM = (mod, isNodeMode, target) => (target = mod != null ? __create(__getProtoOf(mod)) : {}, __copyProps(
    // If the importer is in node compatibility mode or this is not an ESM
    // file that has been converted to a CommonJS file using a Babel-
    // compatible transform (i.e. "__esModule" has not been set), then set
    // "default" to the CommonJS "module.exports" for node compatibility.
    isNodeMode || !mod || !mod.__esModule ? __defProp(target, "default", { value: mod, enumerable: true }) : target,
    mod
  ));

  // node_modules/lodash.debounce/index.js
  var require_lodash = __commonJS({
    "node_modules/lodash.debounce/index.js"(exports, module) {
      var FUNC_ERROR_TEXT = "Expected a function";
      var NAN = 0 / 0;
      var symbolTag = "[object Symbol]";
      var reTrim = /^\s+|\s+$/g;
      var reIsBadHex = /^[-+]0x[0-9a-f]+$/i;
      var reIsBinary = /^0b[01]+$/i;
      var reIsOctal = /^0o[0-7]+$/i;
      var freeParseInt = parseInt;
      var freeGlobal = typeof global == "object" && global && global.Object === Object && global;
      var freeSelf = typeof self == "object" && self && self.Object === Object && self;
      var root = freeGlobal || freeSelf || Function("return this")();
      var objectProto = Object.prototype;
      var objectToString = objectProto.toString;
      var nativeMax = Math.max;
      var nativeMin = Math.min;
      var now = function() {
        return root.Date.now();
      };
      function debounce3(func, wait, options) {
        var lastArgs, lastThis, maxWait, result, timerId, lastCallTime, lastInvokeTime = 0, leading = false, maxing = false, trailing = true;
        if (typeof func != "function") {
          throw new TypeError(FUNC_ERROR_TEXT);
        }
        wait = toNumber(wait) || 0;
        if (isObject(options)) {
          leading = !!options.leading;
          maxing = "maxWait" in options;
          maxWait = maxing ? nativeMax(toNumber(options.maxWait) || 0, wait) : maxWait;
          trailing = "trailing" in options ? !!options.trailing : trailing;
        }
        function invokeFunc(time) {
          var args = lastArgs, thisArg = lastThis;
          lastArgs = lastThis = void 0;
          lastInvokeTime = time;
          result = func.apply(thisArg, args);
          return result;
        }
        function leadingEdge(time) {
          lastInvokeTime = time;
          timerId = setTimeout(timerExpired, wait);
          return leading ? invokeFunc(time) : result;
        }
        function remainingWait(time) {
          var timeSinceLastCall = time - lastCallTime, timeSinceLastInvoke = time - lastInvokeTime, result2 = wait - timeSinceLastCall;
          return maxing ? nativeMin(result2, maxWait - timeSinceLastInvoke) : result2;
        }
        function shouldInvoke(time) {
          var timeSinceLastCall = time - lastCallTime, timeSinceLastInvoke = time - lastInvokeTime;
          return lastCallTime === void 0 || timeSinceLastCall >= wait || timeSinceLastCall < 0 || maxing && timeSinceLastInvoke >= maxWait;
        }
        function timerExpired() {
          var time = now();
          if (shouldInvoke(time)) {
            return trailingEdge(time);
          }
          timerId = setTimeout(timerExpired, remainingWait(time));
        }
        function trailingEdge(time) {
          timerId = void 0;
          if (trailing && lastArgs) {
            return invokeFunc(time);
          }
          lastArgs = lastThis = void 0;
          return result;
        }
        function cancel() {
          if (timerId !== void 0) {
            clearTimeout(timerId);
          }
          lastInvokeTime = 0;
          lastArgs = lastCallTime = lastThis = timerId = void 0;
        }
        function flush() {
          return timerId === void 0 ? result : trailingEdge(now());
        }
        function debounced() {
          var time = now(), isInvoking = shouldInvoke(time);
          lastArgs = arguments;
          lastThis = this;
          lastCallTime = time;
          if (isInvoking) {
            if (timerId === void 0) {
              return leadingEdge(lastCallTime);
            }
            if (maxing) {
              timerId = setTimeout(timerExpired, wait);
              return invokeFunc(lastCallTime);
            }
          }
          if (timerId === void 0) {
            timerId = setTimeout(timerExpired, wait);
          }
          return result;
        }
        debounced.cancel = cancel;
        debounced.flush = flush;
        return debounced;
      }
      function isObject(value) {
        var type = typeof value;
        return !!value && (type == "object" || type == "function");
      }
      function isObjectLike(value) {
        return !!value && typeof value == "object";
      }
      function isSymbol(value) {
        return typeof value == "symbol" || isObjectLike(value) && objectToString.call(value) == symbolTag;
      }
      function toNumber(value) {
        if (typeof value == "number") {
          return value;
        }
        if (isSymbol(value)) {
          return NAN;
        }
        if (isObject(value)) {
          var other = typeof value.valueOf == "function" ? value.valueOf() : value;
          value = isObject(other) ? other + "" : other;
        }
        if (typeof value != "string") {
          return value === 0 ? value : +value;
        }
        value = value.replace(reTrim, "");
        var isBinary = reIsBinary.test(value);
        return isBinary || reIsOctal.test(value) ? freeParseInt(value.slice(2), isBinary ? 2 : 8) : reIsBadHex.test(value) ? NAN : +value;
      }
      module.exports = debounce3;
    }
  });

  // node_modules/@hotwired/stimulus/dist/stimulus.js
  function camelize(value) {
    return value.replace(/(?:[_-])([a-z0-9])/g, (_, char) => char.toUpperCase());
  }
  function namespaceCamelize(value) {
    return camelize(value.replace(/--/g, "-").replace(/__/g, "_"));
  }
  function capitalize(value) {
    return value.charAt(0).toUpperCase() + value.slice(1);
  }
  function dasherize(value) {
    return value.replace(/([A-Z])/g, (_, char) => `-${char.toLowerCase()}`);
  }
  function isSomething(object) {
    return object !== null && object !== void 0;
  }
  function hasProperty(object, property) {
    return Object.prototype.hasOwnProperty.call(object, property);
  }
  function readInheritableStaticArrayValues(constructor, propertyName) {
    const ancestors = getAncestorsForConstructor(constructor);
    return Array.from(ancestors.reduce((values, constructor2) => {
      getOwnStaticArrayValues(constructor2, propertyName).forEach((name) => values.add(name));
      return values;
    }, /* @__PURE__ */ new Set()));
  }
  function readInheritableStaticObjectPairs(constructor, propertyName) {
    const ancestors = getAncestorsForConstructor(constructor);
    return ancestors.reduce((pairs, constructor2) => {
      pairs.push(...getOwnStaticObjectPairs(constructor2, propertyName));
      return pairs;
    }, []);
  }
  function getAncestorsForConstructor(constructor) {
    const ancestors = [];
    while (constructor) {
      ancestors.push(constructor);
      constructor = Object.getPrototypeOf(constructor);
    }
    return ancestors.reverse();
  }
  function getOwnStaticArrayValues(constructor, propertyName) {
    const definition = constructor[propertyName];
    return Array.isArray(definition) ? definition : [];
  }
  function getOwnStaticObjectPairs(constructor, propertyName) {
    const definition = constructor[propertyName];
    return definition ? Object.keys(definition).map((key) => [key, definition[key]]) : [];
  }
  var getOwnKeys = (() => {
    if (typeof Object.getOwnPropertySymbols == "function") {
      return (object) => [...Object.getOwnPropertyNames(object), ...Object.getOwnPropertySymbols(object)];
    } else {
      return Object.getOwnPropertyNames;
    }
  })();
  var extend = (() => {
    function extendWithReflect(constructor) {
      function extended() {
        return Reflect.construct(constructor, arguments, new.target);
      }
      extended.prototype = Object.create(constructor.prototype, {
        constructor: { value: extended }
      });
      Reflect.setPrototypeOf(extended, constructor);
      return extended;
    }
    function testReflectExtension() {
      const a = function() {
        this.a.call(this);
      };
      const b = extendWithReflect(a);
      b.prototype.a = function() {
      };
      return new b();
    }
    try {
      testReflectExtension();
      return extendWithReflect;
    } catch (error) {
      return (constructor) => class extended extends constructor {
      };
    }
  })();
  var defaultSchema = {
    controllerAttribute: "data-controller",
    actionAttribute: "data-action",
    targetAttribute: "data-target",
    targetAttributeForScope: (identifier) => `data-${identifier}-target`,
    outletAttributeForScope: (identifier, outlet) => `data-${identifier}-${outlet}-outlet`,
    keyMappings: Object.assign(Object.assign({ enter: "Enter", tab: "Tab", esc: "Escape", space: " ", up: "ArrowUp", down: "ArrowDown", left: "ArrowLeft", right: "ArrowRight", home: "Home", end: "End", page_up: "PageUp", page_down: "PageDown" }, objectFromEntries("abcdefghijklmnopqrstuvwxyz".split("").map((c) => [c, c]))), objectFromEntries("0123456789".split("").map((n) => [n, n])))
  };
  function objectFromEntries(array) {
    return array.reduce((memo, [k, v]) => Object.assign(Object.assign({}, memo), { [k]: v }), {});
  }
  function ClassPropertiesBlessing(constructor) {
    const classes = readInheritableStaticArrayValues(constructor, "classes");
    return classes.reduce((properties, classDefinition) => {
      return Object.assign(properties, propertiesForClassDefinition(classDefinition));
    }, {});
  }
  function propertiesForClassDefinition(key) {
    return {
      [`${key}Class`]: {
        get() {
          const { classes } = this;
          if (classes.has(key)) {
            return classes.get(key);
          } else {
            const attribute = classes.getAttributeName(key);
            throw new Error(`Missing attribute "${attribute}"`);
          }
        }
      },
      [`${key}Classes`]: {
        get() {
          return this.classes.getAll(key);
        }
      },
      [`has${capitalize(key)}Class`]: {
        get() {
          return this.classes.has(key);
        }
      }
    };
  }
  function OutletPropertiesBlessing(constructor) {
    const outlets = readInheritableStaticArrayValues(constructor, "outlets");
    return outlets.reduce((properties, outletDefinition) => {
      return Object.assign(properties, propertiesForOutletDefinition(outletDefinition));
    }, {});
  }
  function getOutletController(controller, element, identifier) {
    return controller.application.getControllerForElementAndIdentifier(element, identifier);
  }
  function getControllerAndEnsureConnectedScope(controller, element, outletName) {
    let outletController = getOutletController(controller, element, outletName);
    if (outletController)
      return outletController;
    controller.application.router.proposeToConnectScopeForElementAndIdentifier(element, outletName);
    outletController = getOutletController(controller, element, outletName);
    if (outletController)
      return outletController;
  }
  function propertiesForOutletDefinition(name) {
    const camelizedName = namespaceCamelize(name);
    return {
      [`${camelizedName}Outlet`]: {
        get() {
          const outletElement = this.outlets.find(name);
          const selector = this.outlets.getSelectorForOutletName(name);
          if (outletElement) {
            const outletController = getControllerAndEnsureConnectedScope(this, outletElement, name);
            if (outletController)
              return outletController;
            throw new Error(`The provided outlet element is missing an outlet controller "${name}" instance for host controller "${this.identifier}"`);
          }
          throw new Error(`Missing outlet element "${name}" for host controller "${this.identifier}". Stimulus couldn't find a matching outlet element using selector "${selector}".`);
        }
      },
      [`${camelizedName}Outlets`]: {
        get() {
          const outlets = this.outlets.findAll(name);
          if (outlets.length > 0) {
            return outlets.map((outletElement) => {
              const outletController = getControllerAndEnsureConnectedScope(this, outletElement, name);
              if (outletController)
                return outletController;
              console.warn(`The provided outlet element is missing an outlet controller "${name}" instance for host controller "${this.identifier}"`, outletElement);
            }).filter((controller) => controller);
          }
          return [];
        }
      },
      [`${camelizedName}OutletElement`]: {
        get() {
          const outletElement = this.outlets.find(name);
          const selector = this.outlets.getSelectorForOutletName(name);
          if (outletElement) {
            return outletElement;
          } else {
            throw new Error(`Missing outlet element "${name}" for host controller "${this.identifier}". Stimulus couldn't find a matching outlet element using selector "${selector}".`);
          }
        }
      },
      [`${camelizedName}OutletElements`]: {
        get() {
          return this.outlets.findAll(name);
        }
      },
      [`has${capitalize(camelizedName)}Outlet`]: {
        get() {
          return this.outlets.has(name);
        }
      }
    };
  }
  function TargetPropertiesBlessing(constructor) {
    const targets = readInheritableStaticArrayValues(constructor, "targets");
    return targets.reduce((properties, targetDefinition) => {
      return Object.assign(properties, propertiesForTargetDefinition(targetDefinition));
    }, {});
  }
  function propertiesForTargetDefinition(name) {
    return {
      [`${name}Target`]: {
        get() {
          const target = this.targets.find(name);
          if (target) {
            return target;
          } else {
            throw new Error(`Missing target element "${name}" for "${this.identifier}" controller`);
          }
        }
      },
      [`${name}Targets`]: {
        get() {
          return this.targets.findAll(name);
        }
      },
      [`has${capitalize(name)}Target`]: {
        get() {
          return this.targets.has(name);
        }
      }
    };
  }
  function ValuePropertiesBlessing(constructor) {
    const valueDefinitionPairs = readInheritableStaticObjectPairs(constructor, "values");
    const propertyDescriptorMap = {
      valueDescriptorMap: {
        get() {
          return valueDefinitionPairs.reduce((result, valueDefinitionPair) => {
            const valueDescriptor = parseValueDefinitionPair(valueDefinitionPair, this.identifier);
            const attributeName = this.data.getAttributeNameForKey(valueDescriptor.key);
            return Object.assign(result, { [attributeName]: valueDescriptor });
          }, {});
        }
      }
    };
    return valueDefinitionPairs.reduce((properties, valueDefinitionPair) => {
      return Object.assign(properties, propertiesForValueDefinitionPair(valueDefinitionPair));
    }, propertyDescriptorMap);
  }
  function propertiesForValueDefinitionPair(valueDefinitionPair, controller) {
    const definition = parseValueDefinitionPair(valueDefinitionPair, controller);
    const { key, name, reader: read2, writer: write2 } = definition;
    return {
      [name]: {
        get() {
          const value = this.data.get(key);
          if (value !== null) {
            return read2(value);
          } else {
            return definition.defaultValue;
          }
        },
        set(value) {
          if (value === void 0) {
            this.data.delete(key);
          } else {
            this.data.set(key, write2(value));
          }
        }
      },
      [`has${capitalize(name)}`]: {
        get() {
          return this.data.has(key) || definition.hasCustomDefaultValue;
        }
      }
    };
  }
  function parseValueDefinitionPair([token, typeDefinition], controller) {
    return valueDescriptorForTokenAndTypeDefinition({
      controller,
      token,
      typeDefinition
    });
  }
  function parseValueTypeConstant(constant) {
    switch (constant) {
      case Array:
        return "array";
      case Boolean:
        return "boolean";
      case Number:
        return "number";
      case Object:
        return "object";
      case String:
        return "string";
    }
  }
  function parseValueTypeDefault(defaultValue) {
    switch (typeof defaultValue) {
      case "boolean":
        return "boolean";
      case "number":
        return "number";
      case "string":
        return "string";
    }
    if (Array.isArray(defaultValue))
      return "array";
    if (Object.prototype.toString.call(defaultValue) === "[object Object]")
      return "object";
  }
  function parseValueTypeObject(payload) {
    const { controller, token, typeObject } = payload;
    const hasType = isSomething(typeObject.type);
    const hasDefault = isSomething(typeObject.default);
    const fullObject = hasType && hasDefault;
    const onlyType = hasType && !hasDefault;
    const onlyDefault = !hasType && hasDefault;
    const typeFromObject = parseValueTypeConstant(typeObject.type);
    const typeFromDefaultValue = parseValueTypeDefault(payload.typeObject.default);
    if (onlyType)
      return typeFromObject;
    if (onlyDefault)
      return typeFromDefaultValue;
    if (typeFromObject !== typeFromDefaultValue) {
      const propertyPath = controller ? `${controller}.${token}` : token;
      throw new Error(`The specified default value for the Stimulus Value "${propertyPath}" must match the defined type "${typeFromObject}". The provided default value of "${typeObject.default}" is of type "${typeFromDefaultValue}".`);
    }
    if (fullObject)
      return typeFromObject;
  }
  function parseValueTypeDefinition(payload) {
    const { controller, token, typeDefinition } = payload;
    const typeObject = { controller, token, typeObject: typeDefinition };
    const typeFromObject = parseValueTypeObject(typeObject);
    const typeFromDefaultValue = parseValueTypeDefault(typeDefinition);
    const typeFromConstant = parseValueTypeConstant(typeDefinition);
    const type = typeFromObject || typeFromDefaultValue || typeFromConstant;
    if (type)
      return type;
    const propertyPath = controller ? `${controller}.${typeDefinition}` : token;
    throw new Error(`Unknown value type "${propertyPath}" for "${token}" value`);
  }
  function defaultValueForDefinition(typeDefinition) {
    const constant = parseValueTypeConstant(typeDefinition);
    if (constant)
      return defaultValuesByType[constant];
    const hasDefault = hasProperty(typeDefinition, "default");
    const hasType = hasProperty(typeDefinition, "type");
    const typeObject = typeDefinition;
    if (hasDefault)
      return typeObject.default;
    if (hasType) {
      const { type } = typeObject;
      const constantFromType = parseValueTypeConstant(type);
      if (constantFromType)
        return defaultValuesByType[constantFromType];
    }
    return typeDefinition;
  }
  function valueDescriptorForTokenAndTypeDefinition(payload) {
    const { token, typeDefinition } = payload;
    const key = `${dasherize(token)}-value`;
    const type = parseValueTypeDefinition(payload);
    return {
      type,
      key,
      name: camelize(key),
      get defaultValue() {
        return defaultValueForDefinition(typeDefinition);
      },
      get hasCustomDefaultValue() {
        return parseValueTypeDefault(typeDefinition) !== void 0;
      },
      reader: readers[type],
      writer: writers[type] || writers.default
    };
  }
  var defaultValuesByType = {
    get array() {
      return [];
    },
    boolean: false,
    number: 0,
    get object() {
      return {};
    },
    string: ""
  };
  var readers = {
    array(value) {
      const array = JSON.parse(value);
      if (!Array.isArray(array)) {
        throw new TypeError(`expected value of type "array" but instead got value "${value}" of type "${parseValueTypeDefault(array)}"`);
      }
      return array;
    },
    boolean(value) {
      return !(value == "0" || String(value).toLowerCase() == "false");
    },
    number(value) {
      return Number(value.replace(/_/g, ""));
    },
    object(value) {
      const object = JSON.parse(value);
      if (object === null || typeof object != "object" || Array.isArray(object)) {
        throw new TypeError(`expected value of type "object" but instead got value "${value}" of type "${parseValueTypeDefault(object)}"`);
      }
      return object;
    },
    string(value) {
      return value;
    }
  };
  var writers = {
    default: writeString,
    array: writeJSON,
    object: writeJSON
  };
  function writeJSON(value) {
    return JSON.stringify(value);
  }
  function writeString(value) {
    return `${value}`;
  }
  var Controller = class {
    constructor(context) {
      this.context = context;
    }
    static get shouldLoad() {
      return true;
    }
    static afterLoad(_identifier, _application) {
      return;
    }
    get application() {
      return this.context.application;
    }
    get scope() {
      return this.context.scope;
    }
    get element() {
      return this.scope.element;
    }
    get identifier() {
      return this.scope.identifier;
    }
    get targets() {
      return this.scope.targets;
    }
    get outlets() {
      return this.scope.outlets;
    }
    get classes() {
      return this.scope.classes;
    }
    get data() {
      return this.scope.data;
    }
    initialize() {
    }
    connect() {
    }
    disconnect() {
    }
    dispatch(eventName, { target = this.element, detail = {}, prefix = this.identifier, bubbles = true, cancelable = true } = {}) {
      const type = prefix ? `${prefix}:${eventName}` : eventName;
      const event = new CustomEvent(type, { detail, bubbles, cancelable });
      target.dispatchEvent(event);
      return event;
    }
  };
  Controller.blessings = [
    ClassPropertiesBlessing,
    TargetPropertiesBlessing,
    ValuePropertiesBlessing,
    OutletPropertiesBlessing
  ];
  Controller.targets = [];
  Controller.outlets = [];
  Controller.values = {};

  // app/views/components/nested_resource_form_fields/nested_resource_form_fields_controller.js
  var nested_resource_form_fields_controller_default = class extends Controller {
    static targets = ["target", "template", "addButton"];
    static values = {
      wrapperSelector: {
        type: String,
        default: ".nested-resource-form-fields"
      },
      limit: Number
    };
    connect() {
      this.updateState();
    }
    add(e) {
      e.preventDefault();
      const content = this.templateTarget.innerHTML.replace(/NEW_RECORD/g, (/* @__PURE__ */ new Date()).getTime().toString());
      this.targetTarget.insertAdjacentHTML("beforebegin", content);
      const event = new CustomEvent("nested-resource-form-fields:add", { bubbles: true });
      this.element.dispatchEvent(event);
      this.updateState();
    }
    remove(e) {
      e.preventDefault();
      const wrapper = e.target.closest(this.wrapperSelectorValue);
      if (wrapper.dataset.newRecord === "true") {
        wrapper.remove();
      } else {
        wrapper.style.display = "none";
        const input = wrapper.querySelector("input[name*='_destroy']");
        input.value = "1";
      }
      const event = new CustomEvent("nested-resource-form-fields:remove", { bubbles: true });
      this.element.dispatchEvent(event);
      this.updateState();
    }
    updateState() {
      if (!this.hasAddButtonTarget || this.limitValue == 0)
        return;
      if (this.childCount >= this.limitValue)
        this.addButtonTarget.style.display = "none";
      else
        this.addButtonTarget.style.display = "initial";
    }
    get childCount() {
      return this.element.querySelectorAll(this.wrapperSelectorValue).length;
    }
  };

  // app/views/components/tab_bar/tab_bar_controller.js
  var tab_bar_controller_default = class extends Controller {
    connect() {
      console.log(`tab-bar connected: ${this.element}`);
    }
  };

  // app/views/components/toolbar/toolbar_controller.js
  var toolbar_controller_default = class extends Controller {
    connect() {
      console.log(`toolbar connected: ${this.element}`);
    }
  };

  // app/views/components/table_search_input/table_search_input_controller.js
  var table_search_input_controller_default = class extends Controller {
    connect() {
      console.log(`table-search-input connected: ${this.element}`);
    }
  };

  // app/views/components/table_toolbar/table_toolbar_controller.js
  var table_toolbar_controller_default = class extends Controller {
    connect() {
      console.log(`table-toolbar connected: ${this.element}`);
    }
  };

  // app/views/components/table/table_controller.js
  var table_controller_default = class extends Controller {
    connect() {
      console.log(`table connected: ${this.element}`);
    }
  };

  // app/views/components/form/form_controller.js
  var import_lodash = __toESM(require_lodash());
  var form_controller_default = class extends Controller {
    connect() {
      console.log(`form connected: ${this.element}`);
    }
    submit() {
      this.element.requestSubmit();
    }
  };

  // node_modules/flowbite/lib/esm/dom/events.js
  var Events = (
    /** @class */
    function() {
      function Events2(eventType, eventFunctions) {
        if (eventFunctions === void 0) {
          eventFunctions = [];
        }
        this._eventType = eventType;
        this._eventFunctions = eventFunctions;
      }
      Events2.prototype.init = function() {
        var _this = this;
        this._eventFunctions.forEach(function(eventFunction) {
          if (typeof window !== "undefined") {
            window.addEventListener(_this._eventType, eventFunction);
          }
        });
      };
      return Events2;
    }()
  );
  var events_default = Events;

  // node_modules/flowbite/lib/esm/dom/instances.js
  var Instances = (
    /** @class */
    function() {
      function Instances2() {
        this._instances = {
          Accordion: {},
          Carousel: {},
          Collapse: {},
          Dial: {},
          Dismiss: {},
          Drawer: {},
          Dropdown: {},
          Modal: {},
          Popover: {},
          Tabs: {},
          Tooltip: {},
          InputCounter: {},
          CopyClipboard: {}
        };
      }
      Instances2.prototype.addInstance = function(component, instance, id, override) {
        if (override === void 0) {
          override = false;
        }
        if (!this._instances[component]) {
          console.warn("Flowbite: Component ".concat(component, " does not exist."));
          return false;
        }
        if (this._instances[component][id] && !override) {
          console.warn("Flowbite: Instance with ID ".concat(id, " already exists."));
          return;
        }
        if (override && this._instances[component][id]) {
          this._instances[component][id].destroyAndRemoveInstance();
        }
        this._instances[component][id ? id : this._generateRandomId()] = instance;
      };
      Instances2.prototype.getAllInstances = function() {
        return this._instances;
      };
      Instances2.prototype.getInstances = function(component) {
        if (!this._instances[component]) {
          console.warn("Flowbite: Component ".concat(component, " does not exist."));
          return false;
        }
        return this._instances[component];
      };
      Instances2.prototype.getInstance = function(component, id) {
        if (!this._componentAndInstanceCheck(component, id)) {
          return;
        }
        if (!this._instances[component][id]) {
          console.warn("Flowbite: Instance with ID ".concat(id, " does not exist."));
          return;
        }
        return this._instances[component][id];
      };
      Instances2.prototype.destroyAndRemoveInstance = function(component, id) {
        if (!this._componentAndInstanceCheck(component, id)) {
          return;
        }
        this.destroyInstanceObject(component, id);
        this.removeInstance(component, id);
      };
      Instances2.prototype.removeInstance = function(component, id) {
        if (!this._componentAndInstanceCheck(component, id)) {
          return;
        }
        delete this._instances[component][id];
      };
      Instances2.prototype.destroyInstanceObject = function(component, id) {
        if (!this._componentAndInstanceCheck(component, id)) {
          return;
        }
        this._instances[component][id].destroy();
      };
      Instances2.prototype.instanceExists = function(component, id) {
        if (!this._instances[component]) {
          return false;
        }
        if (!this._instances[component][id]) {
          return false;
        }
        return true;
      };
      Instances2.prototype._generateRandomId = function() {
        return Math.random().toString(36).substr(2, 9);
      };
      Instances2.prototype._componentAndInstanceCheck = function(component, id) {
        if (!this._instances[component]) {
          console.warn("Flowbite: Component ".concat(component, " does not exist."));
          return false;
        }
        if (!this._instances[component][id]) {
          console.warn("Flowbite: Instance with ID ".concat(id, " does not exist."));
          return false;
        }
        return true;
      };
      return Instances2;
    }()
  );
  var instances = new Instances();
  var instances_default = instances;
  if (typeof window !== "undefined") {
    window.FlowbiteInstances = instances;
  }

  // node_modules/flowbite/lib/esm/components/accordion/index.js
  var __assign = function() {
    __assign = Object.assign || function(t) {
      for (var s, i = 1, n = arguments.length; i < n; i++) {
        s = arguments[i];
        for (var p in s)
          if (Object.prototype.hasOwnProperty.call(s, p))
            t[p] = s[p];
      }
      return t;
    };
    return __assign.apply(this, arguments);
  };
  var Default = {
    alwaysOpen: false,
    activeClasses: "bg-gray-100 dark:bg-gray-800 text-gray-900 dark:text-white",
    inactiveClasses: "text-gray-500 dark:text-gray-400",
    onOpen: function() {
    },
    onClose: function() {
    },
    onToggle: function() {
    }
  };
  var DefaultInstanceOptions = {
    id: null,
    override: true
  };
  var Accordion = (
    /** @class */
    function() {
      function Accordion2(accordionEl, items, options, instanceOptions) {
        if (accordionEl === void 0) {
          accordionEl = null;
        }
        if (items === void 0) {
          items = [];
        }
        if (options === void 0) {
          options = Default;
        }
        if (instanceOptions === void 0) {
          instanceOptions = DefaultInstanceOptions;
        }
        this._instanceId = instanceOptions.id ? instanceOptions.id : accordionEl.id;
        this._accordionEl = accordionEl;
        this._items = items;
        this._options = __assign(__assign({}, Default), options);
        this._initialized = false;
        this.init();
        instances_default.addInstance("Accordion", this, this._instanceId, instanceOptions.override);
      }
      Accordion2.prototype.init = function() {
        var _this = this;
        if (this._items.length && !this._initialized) {
          this._items.forEach(function(item) {
            if (item.active) {
              _this.open(item.id);
            }
            var clickHandler = function() {
              _this.toggle(item.id);
            };
            item.triggerEl.addEventListener("click", clickHandler);
            item.clickHandler = clickHandler;
          });
          this._initialized = true;
        }
      };
      Accordion2.prototype.destroy = function() {
        if (this._items.length && this._initialized) {
          this._items.forEach(function(item) {
            item.triggerEl.removeEventListener("click", item.clickHandler);
            delete item.clickHandler;
          });
          this._initialized = false;
        }
      };
      Accordion2.prototype.removeInstance = function() {
        instances_default.removeInstance("Accordion", this._instanceId);
      };
      Accordion2.prototype.destroyAndRemoveInstance = function() {
        this.destroy();
        this.removeInstance();
      };
      Accordion2.prototype.getItem = function(id) {
        return this._items.filter(function(item) {
          return item.id === id;
        })[0];
      };
      Accordion2.prototype.open = function(id) {
        var _a, _b;
        var _this = this;
        var item = this.getItem(id);
        if (!this._options.alwaysOpen) {
          this._items.map(function(i) {
            var _a2, _b2;
            if (i !== item) {
              (_a2 = i.triggerEl.classList).remove.apply(_a2, _this._options.activeClasses.split(" "));
              (_b2 = i.triggerEl.classList).add.apply(_b2, _this._options.inactiveClasses.split(" "));
              i.targetEl.classList.add("hidden");
              i.triggerEl.setAttribute("aria-expanded", "false");
              i.active = false;
              if (i.iconEl) {
                i.iconEl.classList.add("rotate-180");
              }
            }
          });
        }
        (_a = item.triggerEl.classList).add.apply(_a, this._options.activeClasses.split(" "));
        (_b = item.triggerEl.classList).remove.apply(_b, this._options.inactiveClasses.split(" "));
        item.triggerEl.setAttribute("aria-expanded", "true");
        item.targetEl.classList.remove("hidden");
        item.active = true;
        if (item.iconEl) {
          item.iconEl.classList.remove("rotate-180");
        }
        this._options.onOpen(this, item);
      };
      Accordion2.prototype.toggle = function(id) {
        var item = this.getItem(id);
        if (item.active) {
          this.close(id);
        } else {
          this.open(id);
        }
        this._options.onToggle(this, item);
      };
      Accordion2.prototype.close = function(id) {
        var _a, _b;
        var item = this.getItem(id);
        (_a = item.triggerEl.classList).remove.apply(_a, this._options.activeClasses.split(" "));
        (_b = item.triggerEl.classList).add.apply(_b, this._options.inactiveClasses.split(" "));
        item.targetEl.classList.add("hidden");
        item.triggerEl.setAttribute("aria-expanded", "false");
        item.active = false;
        if (item.iconEl) {
          item.iconEl.classList.add("rotate-180");
        }
        this._options.onClose(this, item);
      };
      Accordion2.prototype.updateOnOpen = function(callback) {
        this._options.onOpen = callback;
      };
      Accordion2.prototype.updateOnClose = function(callback) {
        this._options.onClose = callback;
      };
      Accordion2.prototype.updateOnToggle = function(callback) {
        this._options.onToggle = callback;
      };
      return Accordion2;
    }()
  );
  function initAccordions() {
    document.querySelectorAll("[data-accordion]").forEach(function($accordionEl) {
      var alwaysOpen = $accordionEl.getAttribute("data-accordion");
      var activeClasses = $accordionEl.getAttribute("data-active-classes");
      var inactiveClasses = $accordionEl.getAttribute("data-inactive-classes");
      var items = [];
      $accordionEl.querySelectorAll("[data-accordion-target]").forEach(function($triggerEl) {
        if ($triggerEl.closest("[data-accordion]") === $accordionEl) {
          var item = {
            id: $triggerEl.getAttribute("data-accordion-target"),
            triggerEl: $triggerEl,
            targetEl: document.querySelector($triggerEl.getAttribute("data-accordion-target")),
            iconEl: $triggerEl.querySelector("[data-accordion-icon]"),
            active: $triggerEl.getAttribute("aria-expanded") === "true" ? true : false
          };
          items.push(item);
        }
      });
      new Accordion($accordionEl, items, {
        alwaysOpen: alwaysOpen === "open" ? true : false,
        activeClasses: activeClasses ? activeClasses : Default.activeClasses,
        inactiveClasses: inactiveClasses ? inactiveClasses : Default.inactiveClasses
      });
    });
  }
  if (typeof window !== "undefined") {
    window.Accordion = Accordion;
    window.initAccordions = initAccordions;
  }

  // node_modules/flowbite/lib/esm/components/collapse/index.js
  var __assign2 = function() {
    __assign2 = Object.assign || function(t) {
      for (var s, i = 1, n = arguments.length; i < n; i++) {
        s = arguments[i];
        for (var p in s)
          if (Object.prototype.hasOwnProperty.call(s, p))
            t[p] = s[p];
      }
      return t;
    };
    return __assign2.apply(this, arguments);
  };
  var Default2 = {
    onCollapse: function() {
    },
    onExpand: function() {
    },
    onToggle: function() {
    }
  };
  var DefaultInstanceOptions2 = {
    id: null,
    override: true
  };
  var Collapse = (
    /** @class */
    function() {
      function Collapse2(targetEl, triggerEl, options, instanceOptions) {
        if (targetEl === void 0) {
          targetEl = null;
        }
        if (triggerEl === void 0) {
          triggerEl = null;
        }
        if (options === void 0) {
          options = Default2;
        }
        if (instanceOptions === void 0) {
          instanceOptions = DefaultInstanceOptions2;
        }
        this._instanceId = instanceOptions.id ? instanceOptions.id : targetEl.id;
        this._targetEl = targetEl;
        this._triggerEl = triggerEl;
        this._options = __assign2(__assign2({}, Default2), options);
        this._visible = false;
        this._initialized = false;
        this.init();
        instances_default.addInstance("Collapse", this, this._instanceId, instanceOptions.override);
      }
      Collapse2.prototype.init = function() {
        var _this = this;
        if (this._triggerEl && this._targetEl && !this._initialized) {
          if (this._triggerEl.hasAttribute("aria-expanded")) {
            this._visible = this._triggerEl.getAttribute("aria-expanded") === "true";
          } else {
            this._visible = !this._targetEl.classList.contains("hidden");
          }
          this._clickHandler = function() {
            _this.toggle();
          };
          this._triggerEl.addEventListener("click", this._clickHandler);
          this._initialized = true;
        }
      };
      Collapse2.prototype.destroy = function() {
        if (this._triggerEl && this._initialized) {
          this._triggerEl.removeEventListener("click", this._clickHandler);
          this._initialized = false;
        }
      };
      Collapse2.prototype.removeInstance = function() {
        instances_default.removeInstance("Collapse", this._instanceId);
      };
      Collapse2.prototype.destroyAndRemoveInstance = function() {
        this.destroy();
        this.removeInstance();
      };
      Collapse2.prototype.collapse = function() {
        this._targetEl.classList.add("hidden");
        if (this._triggerEl) {
          this._triggerEl.setAttribute("aria-expanded", "false");
        }
        this._visible = false;
        this._options.onCollapse(this);
      };
      Collapse2.prototype.expand = function() {
        this._targetEl.classList.remove("hidden");
        if (this._triggerEl) {
          this._triggerEl.setAttribute("aria-expanded", "true");
        }
        this._visible = true;
        this._options.onExpand(this);
      };
      Collapse2.prototype.toggle = function() {
        if (this._visible) {
          this.collapse();
        } else {
          this.expand();
        }
        this._options.onToggle(this);
      };
      Collapse2.prototype.updateOnCollapse = function(callback) {
        this._options.onCollapse = callback;
      };
      Collapse2.prototype.updateOnExpand = function(callback) {
        this._options.onExpand = callback;
      };
      Collapse2.prototype.updateOnToggle = function(callback) {
        this._options.onToggle = callback;
      };
      return Collapse2;
    }()
  );
  function initCollapses() {
    document.querySelectorAll("[data-collapse-toggle]").forEach(function($triggerEl) {
      var targetId = $triggerEl.getAttribute("data-collapse-toggle");
      var $targetEl = document.getElementById(targetId);
      if ($targetEl) {
        if (!instances_default.instanceExists("Collapse", $targetEl.getAttribute("id"))) {
          new Collapse($targetEl, $triggerEl);
        } else {
          new Collapse($targetEl, $triggerEl, {}, {
            id: $targetEl.getAttribute("id") + "_" + instances_default._generateRandomId()
          });
        }
      } else {
        console.error('The target element with id "'.concat(targetId, '" does not exist. Please check the data-collapse-toggle attribute.'));
      }
    });
  }
  if (typeof window !== "undefined") {
    window.Collapse = Collapse;
    window.initCollapses = initCollapses;
  }

  // node_modules/flowbite/lib/esm/components/carousel/index.js
  var __assign3 = function() {
    __assign3 = Object.assign || function(t) {
      for (var s, i = 1, n = arguments.length; i < n; i++) {
        s = arguments[i];
        for (var p in s)
          if (Object.prototype.hasOwnProperty.call(s, p))
            t[p] = s[p];
      }
      return t;
    };
    return __assign3.apply(this, arguments);
  };
  var Default3 = {
    defaultPosition: 0,
    indicators: {
      items: [],
      activeClasses: "bg-white dark:bg-gray-800",
      inactiveClasses: "bg-white/50 dark:bg-gray-800/50 hover:bg-white dark:hover:bg-gray-800"
    },
    interval: 3e3,
    onNext: function() {
    },
    onPrev: function() {
    },
    onChange: function() {
    }
  };
  var DefaultInstanceOptions3 = {
    id: null,
    override: true
  };
  var Carousel = (
    /** @class */
    function() {
      function Carousel2(carouselEl, items, options, instanceOptions) {
        if (carouselEl === void 0) {
          carouselEl = null;
        }
        if (items === void 0) {
          items = [];
        }
        if (options === void 0) {
          options = Default3;
        }
        if (instanceOptions === void 0) {
          instanceOptions = DefaultInstanceOptions3;
        }
        this._instanceId = instanceOptions.id ? instanceOptions.id : carouselEl.id;
        this._carouselEl = carouselEl;
        this._items = items;
        this._options = __assign3(__assign3(__assign3({}, Default3), options), { indicators: __assign3(__assign3({}, Default3.indicators), options.indicators) });
        this._activeItem = this.getItem(this._options.defaultPosition);
        this._indicators = this._options.indicators.items;
        this._intervalDuration = this._options.interval;
        this._intervalInstance = null;
        this._initialized = false;
        this.init();
        instances_default.addInstance("Carousel", this, this._instanceId, instanceOptions.override);
      }
      Carousel2.prototype.init = function() {
        var _this = this;
        if (this._items.length && !this._initialized) {
          this._items.map(function(item) {
            item.el.classList.add("absolute", "inset-0", "transition-transform", "transform");
          });
          if (this.getActiveItem()) {
            this.slideTo(this.getActiveItem().position);
          } else {
            this.slideTo(0);
          }
          this._indicators.map(function(indicator, position) {
            indicator.el.addEventListener("click", function() {
              _this.slideTo(position);
            });
          });
          this._initialized = true;
        }
      };
      Carousel2.prototype.destroy = function() {
        if (this._initialized) {
          this._initialized = false;
        }
      };
      Carousel2.prototype.removeInstance = function() {
        instances_default.removeInstance("Carousel", this._instanceId);
      };
      Carousel2.prototype.destroyAndRemoveInstance = function() {
        this.destroy();
        this.removeInstance();
      };
      Carousel2.prototype.getItem = function(position) {
        return this._items[position];
      };
      Carousel2.prototype.slideTo = function(position) {
        var nextItem = this._items[position];
        var rotationItems = {
          left: nextItem.position === 0 ? this._items[this._items.length - 1] : this._items[nextItem.position - 1],
          middle: nextItem,
          right: nextItem.position === this._items.length - 1 ? this._items[0] : this._items[nextItem.position + 1]
        };
        this._rotate(rotationItems);
        this._setActiveItem(nextItem);
        if (this._intervalInstance) {
          this.pause();
          this.cycle();
        }
        this._options.onChange(this);
      };
      Carousel2.prototype.next = function() {
        var activeItem = this.getActiveItem();
        var nextItem = null;
        if (activeItem.position === this._items.length - 1) {
          nextItem = this._items[0];
        } else {
          nextItem = this._items[activeItem.position + 1];
        }
        this.slideTo(nextItem.position);
        this._options.onNext(this);
      };
      Carousel2.prototype.prev = function() {
        var activeItem = this.getActiveItem();
        var prevItem = null;
        if (activeItem.position === 0) {
          prevItem = this._items[this._items.length - 1];
        } else {
          prevItem = this._items[activeItem.position - 1];
        }
        this.slideTo(prevItem.position);
        this._options.onPrev(this);
      };
      Carousel2.prototype._rotate = function(rotationItems) {
        this._items.map(function(item) {
          item.el.classList.add("hidden");
        });
        if (this._items.length === 1) {
          rotationItems.middle.el.classList.remove("-translate-x-full", "translate-x-full", "translate-x-0", "hidden", "z-10");
          rotationItems.middle.el.classList.add("translate-x-0", "z-20");
          return;
        }
        rotationItems.left.el.classList.remove("-translate-x-full", "translate-x-full", "translate-x-0", "hidden", "z-20");
        rotationItems.left.el.classList.add("-translate-x-full", "z-10");
        rotationItems.middle.el.classList.remove("-translate-x-full", "translate-x-full", "translate-x-0", "hidden", "z-10");
        rotationItems.middle.el.classList.add("translate-x-0", "z-30");
        rotationItems.right.el.classList.remove("-translate-x-full", "translate-x-full", "translate-x-0", "hidden", "z-30");
        rotationItems.right.el.classList.add("translate-x-full", "z-20");
      };
      Carousel2.prototype.cycle = function() {
        var _this = this;
        if (typeof window !== "undefined") {
          this._intervalInstance = window.setInterval(function() {
            _this.next();
          }, this._intervalDuration);
        }
      };
      Carousel2.prototype.pause = function() {
        clearInterval(this._intervalInstance);
      };
      Carousel2.prototype.getActiveItem = function() {
        return this._activeItem;
      };
      Carousel2.prototype._setActiveItem = function(item) {
        var _a, _b;
        var _this = this;
        this._activeItem = item;
        var position = item.position;
        if (this._indicators.length) {
          this._indicators.map(function(indicator) {
            var _a2, _b2;
            indicator.el.setAttribute("aria-current", "false");
            (_a2 = indicator.el.classList).remove.apply(_a2, _this._options.indicators.activeClasses.split(" "));
            (_b2 = indicator.el.classList).add.apply(_b2, _this._options.indicators.inactiveClasses.split(" "));
          });
          (_a = this._indicators[position].el.classList).add.apply(_a, this._options.indicators.activeClasses.split(" "));
          (_b = this._indicators[position].el.classList).remove.apply(_b, this._options.indicators.inactiveClasses.split(" "));
          this._indicators[position].el.setAttribute("aria-current", "true");
        }
      };
      Carousel2.prototype.updateOnNext = function(callback) {
        this._options.onNext = callback;
      };
      Carousel2.prototype.updateOnPrev = function(callback) {
        this._options.onPrev = callback;
      };
      Carousel2.prototype.updateOnChange = function(callback) {
        this._options.onChange = callback;
      };
      return Carousel2;
    }()
  );
  function initCarousels() {
    document.querySelectorAll("[data-carousel]").forEach(function($carouselEl) {
      var interval = $carouselEl.getAttribute("data-carousel-interval");
      var slide = $carouselEl.getAttribute("data-carousel") === "slide" ? true : false;
      var items = [];
      var defaultPosition = 0;
      if ($carouselEl.querySelectorAll("[data-carousel-item]").length) {
        Array.from($carouselEl.querySelectorAll("[data-carousel-item]")).map(function($carouselItemEl, position) {
          items.push({
            position,
            el: $carouselItemEl
          });
          if ($carouselItemEl.getAttribute("data-carousel-item") === "active") {
            defaultPosition = position;
          }
        });
      }
      var indicators = [];
      if ($carouselEl.querySelectorAll("[data-carousel-slide-to]").length) {
        Array.from($carouselEl.querySelectorAll("[data-carousel-slide-to]")).map(function($indicatorEl) {
          indicators.push({
            position: parseInt($indicatorEl.getAttribute("data-carousel-slide-to")),
            el: $indicatorEl
          });
        });
      }
      var carousel = new Carousel($carouselEl, items, {
        defaultPosition,
        indicators: {
          items: indicators
        },
        interval: interval ? interval : Default3.interval
      });
      if (slide) {
        carousel.cycle();
      }
      var carouselNextEl = $carouselEl.querySelector("[data-carousel-next]");
      var carouselPrevEl = $carouselEl.querySelector("[data-carousel-prev]");
      if (carouselNextEl) {
        carouselNextEl.addEventListener("click", function() {
          carousel.next();
        });
      }
      if (carouselPrevEl) {
        carouselPrevEl.addEventListener("click", function() {
          carousel.prev();
        });
      }
    });
  }
  if (typeof window !== "undefined") {
    window.Carousel = Carousel;
    window.initCarousels = initCarousels;
  }

  // node_modules/flowbite/lib/esm/components/dismiss/index.js
  var __assign4 = function() {
    __assign4 = Object.assign || function(t) {
      for (var s, i = 1, n = arguments.length; i < n; i++) {
        s = arguments[i];
        for (var p in s)
          if (Object.prototype.hasOwnProperty.call(s, p))
            t[p] = s[p];
      }
      return t;
    };
    return __assign4.apply(this, arguments);
  };
  var Default4 = {
    transition: "transition-opacity",
    duration: 300,
    timing: "ease-out",
    onHide: function() {
    }
  };
  var DefaultInstanceOptions4 = {
    id: null,
    override: true
  };
  var Dismiss = (
    /** @class */
    function() {
      function Dismiss2(targetEl, triggerEl, options, instanceOptions) {
        if (targetEl === void 0) {
          targetEl = null;
        }
        if (triggerEl === void 0) {
          triggerEl = null;
        }
        if (options === void 0) {
          options = Default4;
        }
        if (instanceOptions === void 0) {
          instanceOptions = DefaultInstanceOptions4;
        }
        this._instanceId = instanceOptions.id ? instanceOptions.id : targetEl.id;
        this._targetEl = targetEl;
        this._triggerEl = triggerEl;
        this._options = __assign4(__assign4({}, Default4), options);
        this._initialized = false;
        this.init();
        instances_default.addInstance("Dismiss", this, this._instanceId, instanceOptions.override);
      }
      Dismiss2.prototype.init = function() {
        var _this = this;
        if (this._triggerEl && this._targetEl && !this._initialized) {
          this._clickHandler = function() {
            _this.hide();
          };
          this._triggerEl.addEventListener("click", this._clickHandler);
          this._initialized = true;
        }
      };
      Dismiss2.prototype.destroy = function() {
        if (this._triggerEl && this._initialized) {
          this._triggerEl.removeEventListener("click", this._clickHandler);
          this._initialized = false;
        }
      };
      Dismiss2.prototype.removeInstance = function() {
        instances_default.removeInstance("Dismiss", this._instanceId);
      };
      Dismiss2.prototype.destroyAndRemoveInstance = function() {
        this.destroy();
        this.removeInstance();
      };
      Dismiss2.prototype.hide = function() {
        var _this = this;
        this._targetEl.classList.add(this._options.transition, "duration-".concat(this._options.duration), this._options.timing, "opacity-0");
        setTimeout(function() {
          _this._targetEl.classList.add("hidden");
        }, this._options.duration);
        this._options.onHide(this, this._targetEl);
      };
      Dismiss2.prototype.updateOnHide = function(callback) {
        this._options.onHide = callback;
      };
      return Dismiss2;
    }()
  );
  function initDismisses() {
    document.querySelectorAll("[data-dismiss-target]").forEach(function($triggerEl) {
      var targetId = $triggerEl.getAttribute("data-dismiss-target");
      var $dismissEl = document.querySelector(targetId);
      if ($dismissEl) {
        new Dismiss($dismissEl, $triggerEl);
      } else {
        console.error('The dismiss element with id "'.concat(targetId, '" does not exist. Please check the data-dismiss-target attribute.'));
      }
    });
  }
  if (typeof window !== "undefined") {
    window.Dismiss = Dismiss;
    window.initDismisses = initDismisses;
  }
  var dismiss_default = Dismiss;

  // node_modules/@popperjs/core/lib/enums.js
  var top = "top";
  var bottom = "bottom";
  var right = "right";
  var left = "left";
  var auto = "auto";
  var basePlacements = [top, bottom, right, left];
  var start = "start";
  var end = "end";
  var clippingParents = "clippingParents";
  var viewport = "viewport";
  var popper = "popper";
  var reference = "reference";
  var variationPlacements = /* @__PURE__ */ basePlacements.reduce(function(acc, placement) {
    return acc.concat([placement + "-" + start, placement + "-" + end]);
  }, []);
  var placements = /* @__PURE__ */ [].concat(basePlacements, [auto]).reduce(function(acc, placement) {
    return acc.concat([placement, placement + "-" + start, placement + "-" + end]);
  }, []);
  var beforeRead = "beforeRead";
  var read = "read";
  var afterRead = "afterRead";
  var beforeMain = "beforeMain";
  var main = "main";
  var afterMain = "afterMain";
  var beforeWrite = "beforeWrite";
  var write = "write";
  var afterWrite = "afterWrite";
  var modifierPhases = [beforeRead, read, afterRead, beforeMain, main, afterMain, beforeWrite, write, afterWrite];

  // node_modules/@popperjs/core/lib/dom-utils/getNodeName.js
  function getNodeName(element) {
    return element ? (element.nodeName || "").toLowerCase() : null;
  }

  // node_modules/@popperjs/core/lib/dom-utils/getWindow.js
  function getWindow(node) {
    if (node == null) {
      return window;
    }
    if (node.toString() !== "[object Window]") {
      var ownerDocument = node.ownerDocument;
      return ownerDocument ? ownerDocument.defaultView || window : window;
    }
    return node;
  }

  // node_modules/@popperjs/core/lib/dom-utils/instanceOf.js
  function isElement(node) {
    var OwnElement = getWindow(node).Element;
    return node instanceof OwnElement || node instanceof Element;
  }
  function isHTMLElement(node) {
    var OwnElement = getWindow(node).HTMLElement;
    return node instanceof OwnElement || node instanceof HTMLElement;
  }
  function isShadowRoot(node) {
    if (typeof ShadowRoot === "undefined") {
      return false;
    }
    var OwnElement = getWindow(node).ShadowRoot;
    return node instanceof OwnElement || node instanceof ShadowRoot;
  }

  // node_modules/@popperjs/core/lib/modifiers/applyStyles.js
  function applyStyles(_ref) {
    var state = _ref.state;
    Object.keys(state.elements).forEach(function(name) {
      var style = state.styles[name] || {};
      var attributes = state.attributes[name] || {};
      var element = state.elements[name];
      if (!isHTMLElement(element) || !getNodeName(element)) {
        return;
      }
      Object.assign(element.style, style);
      Object.keys(attributes).forEach(function(name2) {
        var value = attributes[name2];
        if (value === false) {
          element.removeAttribute(name2);
        } else {
          element.setAttribute(name2, value === true ? "" : value);
        }
      });
    });
  }
  function effect(_ref2) {
    var state = _ref2.state;
    var initialStyles = {
      popper: {
        position: state.options.strategy,
        left: "0",
        top: "0",
        margin: "0"
      },
      arrow: {
        position: "absolute"
      },
      reference: {}
    };
    Object.assign(state.elements.popper.style, initialStyles.popper);
    state.styles = initialStyles;
    if (state.elements.arrow) {
      Object.assign(state.elements.arrow.style, initialStyles.arrow);
    }
    return function() {
      Object.keys(state.elements).forEach(function(name) {
        var element = state.elements[name];
        var attributes = state.attributes[name] || {};
        var styleProperties = Object.keys(state.styles.hasOwnProperty(name) ? state.styles[name] : initialStyles[name]);
        var style = styleProperties.reduce(function(style2, property) {
          style2[property] = "";
          return style2;
        }, {});
        if (!isHTMLElement(element) || !getNodeName(element)) {
          return;
        }
        Object.assign(element.style, style);
        Object.keys(attributes).forEach(function(attribute) {
          element.removeAttribute(attribute);
        });
      });
    };
  }
  var applyStyles_default = {
    name: "applyStyles",
    enabled: true,
    phase: "write",
    fn: applyStyles,
    effect,
    requires: ["computeStyles"]
  };

  // node_modules/@popperjs/core/lib/utils/getBasePlacement.js
  function getBasePlacement(placement) {
    return placement.split("-")[0];
  }

  // node_modules/@popperjs/core/lib/utils/math.js
  var max = Math.max;
  var min = Math.min;
  var round = Math.round;

  // node_modules/@popperjs/core/lib/utils/userAgent.js
  function getUAString() {
    var uaData = navigator.userAgentData;
    if (uaData != null && uaData.brands && Array.isArray(uaData.brands)) {
      return uaData.brands.map(function(item) {
        return item.brand + "/" + item.version;
      }).join(" ");
    }
    return navigator.userAgent;
  }

  // node_modules/@popperjs/core/lib/dom-utils/isLayoutViewport.js
  function isLayoutViewport() {
    return !/^((?!chrome|android).)*safari/i.test(getUAString());
  }

  // node_modules/@popperjs/core/lib/dom-utils/getBoundingClientRect.js
  function getBoundingClientRect(element, includeScale, isFixedStrategy) {
    if (includeScale === void 0) {
      includeScale = false;
    }
    if (isFixedStrategy === void 0) {
      isFixedStrategy = false;
    }
    var clientRect = element.getBoundingClientRect();
    var scaleX = 1;
    var scaleY = 1;
    if (includeScale && isHTMLElement(element)) {
      scaleX = element.offsetWidth > 0 ? round(clientRect.width) / element.offsetWidth || 1 : 1;
      scaleY = element.offsetHeight > 0 ? round(clientRect.height) / element.offsetHeight || 1 : 1;
    }
    var _ref = isElement(element) ? getWindow(element) : window, visualViewport = _ref.visualViewport;
    var addVisualOffsets = !isLayoutViewport() && isFixedStrategy;
    var x = (clientRect.left + (addVisualOffsets && visualViewport ? visualViewport.offsetLeft : 0)) / scaleX;
    var y = (clientRect.top + (addVisualOffsets && visualViewport ? visualViewport.offsetTop : 0)) / scaleY;
    var width = clientRect.width / scaleX;
    var height = clientRect.height / scaleY;
    return {
      width,
      height,
      top: y,
      right: x + width,
      bottom: y + height,
      left: x,
      x,
      y
    };
  }

  // node_modules/@popperjs/core/lib/dom-utils/getLayoutRect.js
  function getLayoutRect(element) {
    var clientRect = getBoundingClientRect(element);
    var width = element.offsetWidth;
    var height = element.offsetHeight;
    if (Math.abs(clientRect.width - width) <= 1) {
      width = clientRect.width;
    }
    if (Math.abs(clientRect.height - height) <= 1) {
      height = clientRect.height;
    }
    return {
      x: element.offsetLeft,
      y: element.offsetTop,
      width,
      height
    };
  }

  // node_modules/@popperjs/core/lib/dom-utils/contains.js
  function contains(parent, child) {
    var rootNode = child.getRootNode && child.getRootNode();
    if (parent.contains(child)) {
      return true;
    } else if (rootNode && isShadowRoot(rootNode)) {
      var next = child;
      do {
        if (next && parent.isSameNode(next)) {
          return true;
        }
        next = next.parentNode || next.host;
      } while (next);
    }
    return false;
  }

  // node_modules/@popperjs/core/lib/dom-utils/getComputedStyle.js
  function getComputedStyle(element) {
    return getWindow(element).getComputedStyle(element);
  }

  // node_modules/@popperjs/core/lib/dom-utils/isTableElement.js
  function isTableElement(element) {
    return ["table", "td", "th"].indexOf(getNodeName(element)) >= 0;
  }

  // node_modules/@popperjs/core/lib/dom-utils/getDocumentElement.js
  function getDocumentElement(element) {
    return ((isElement(element) ? element.ownerDocument : (
      // $FlowFixMe[prop-missing]
      element.document
    )) || window.document).documentElement;
  }

  // node_modules/@popperjs/core/lib/dom-utils/getParentNode.js
  function getParentNode(element) {
    if (getNodeName(element) === "html") {
      return element;
    }
    return (
      // this is a quicker (but less type safe) way to save quite some bytes from the bundle
      // $FlowFixMe[incompatible-return]
      // $FlowFixMe[prop-missing]
      element.assignedSlot || // step into the shadow DOM of the parent of a slotted node
      element.parentNode || // DOM Element detected
      (isShadowRoot(element) ? element.host : null) || // ShadowRoot detected
      // $FlowFixMe[incompatible-call]: HTMLElement is a Node
      getDocumentElement(element)
    );
  }

  // node_modules/@popperjs/core/lib/dom-utils/getOffsetParent.js
  function getTrueOffsetParent(element) {
    if (!isHTMLElement(element) || // https://github.com/popperjs/popper-core/issues/837
    getComputedStyle(element).position === "fixed") {
      return null;
    }
    return element.offsetParent;
  }
  function getContainingBlock(element) {
    var isFirefox = /firefox/i.test(getUAString());
    var isIE = /Trident/i.test(getUAString());
    if (isIE && isHTMLElement(element)) {
      var elementCss = getComputedStyle(element);
      if (elementCss.position === "fixed") {
        return null;
      }
    }
    var currentNode = getParentNode(element);
    if (isShadowRoot(currentNode)) {
      currentNode = currentNode.host;
    }
    while (isHTMLElement(currentNode) && ["html", "body"].indexOf(getNodeName(currentNode)) < 0) {
      var css = getComputedStyle(currentNode);
      if (css.transform !== "none" || css.perspective !== "none" || css.contain === "paint" || ["transform", "perspective"].indexOf(css.willChange) !== -1 || isFirefox && css.willChange === "filter" || isFirefox && css.filter && css.filter !== "none") {
        return currentNode;
      } else {
        currentNode = currentNode.parentNode;
      }
    }
    return null;
  }
  function getOffsetParent(element) {
    var window2 = getWindow(element);
    var offsetParent = getTrueOffsetParent(element);
    while (offsetParent && isTableElement(offsetParent) && getComputedStyle(offsetParent).position === "static") {
      offsetParent = getTrueOffsetParent(offsetParent);
    }
    if (offsetParent && (getNodeName(offsetParent) === "html" || getNodeName(offsetParent) === "body" && getComputedStyle(offsetParent).position === "static")) {
      return window2;
    }
    return offsetParent || getContainingBlock(element) || window2;
  }

  // node_modules/@popperjs/core/lib/utils/getMainAxisFromPlacement.js
  function getMainAxisFromPlacement(placement) {
    return ["top", "bottom"].indexOf(placement) >= 0 ? "x" : "y";
  }

  // node_modules/@popperjs/core/lib/utils/within.js
  function within(min2, value, max2) {
    return max(min2, min(value, max2));
  }
  function withinMaxClamp(min2, value, max2) {
    var v = within(min2, value, max2);
    return v > max2 ? max2 : v;
  }

  // node_modules/@popperjs/core/lib/utils/getFreshSideObject.js
  function getFreshSideObject() {
    return {
      top: 0,
      right: 0,
      bottom: 0,
      left: 0
    };
  }

  // node_modules/@popperjs/core/lib/utils/mergePaddingObject.js
  function mergePaddingObject(paddingObject) {
    return Object.assign({}, getFreshSideObject(), paddingObject);
  }

  // node_modules/@popperjs/core/lib/utils/expandToHashMap.js
  function expandToHashMap(value, keys) {
    return keys.reduce(function(hashMap, key) {
      hashMap[key] = value;
      return hashMap;
    }, {});
  }

  // node_modules/@popperjs/core/lib/modifiers/arrow.js
  var toPaddingObject = function toPaddingObject2(padding, state) {
    padding = typeof padding === "function" ? padding(Object.assign({}, state.rects, {
      placement: state.placement
    })) : padding;
    return mergePaddingObject(typeof padding !== "number" ? padding : expandToHashMap(padding, basePlacements));
  };
  function arrow(_ref) {
    var _state$modifiersData$;
    var state = _ref.state, name = _ref.name, options = _ref.options;
    var arrowElement = state.elements.arrow;
    var popperOffsets2 = state.modifiersData.popperOffsets;
    var basePlacement = getBasePlacement(state.placement);
    var axis = getMainAxisFromPlacement(basePlacement);
    var isVertical = [left, right].indexOf(basePlacement) >= 0;
    var len = isVertical ? "height" : "width";
    if (!arrowElement || !popperOffsets2) {
      return;
    }
    var paddingObject = toPaddingObject(options.padding, state);
    var arrowRect = getLayoutRect(arrowElement);
    var minProp = axis === "y" ? top : left;
    var maxProp = axis === "y" ? bottom : right;
    var endDiff = state.rects.reference[len] + state.rects.reference[axis] - popperOffsets2[axis] - state.rects.popper[len];
    var startDiff = popperOffsets2[axis] - state.rects.reference[axis];
    var arrowOffsetParent = getOffsetParent(arrowElement);
    var clientSize = arrowOffsetParent ? axis === "y" ? arrowOffsetParent.clientHeight || 0 : arrowOffsetParent.clientWidth || 0 : 0;
    var centerToReference = endDiff / 2 - startDiff / 2;
    var min2 = paddingObject[minProp];
    var max2 = clientSize - arrowRect[len] - paddingObject[maxProp];
    var center = clientSize / 2 - arrowRect[len] / 2 + centerToReference;
    var offset2 = within(min2, center, max2);
    var axisProp = axis;
    state.modifiersData[name] = (_state$modifiersData$ = {}, _state$modifiersData$[axisProp] = offset2, _state$modifiersData$.centerOffset = offset2 - center, _state$modifiersData$);
  }
  function effect2(_ref2) {
    var state = _ref2.state, options = _ref2.options;
    var _options$element = options.element, arrowElement = _options$element === void 0 ? "[data-popper-arrow]" : _options$element;
    if (arrowElement == null) {
      return;
    }
    if (typeof arrowElement === "string") {
      arrowElement = state.elements.popper.querySelector(arrowElement);
      if (!arrowElement) {
        return;
      }
    }
    if (!contains(state.elements.popper, arrowElement)) {
      return;
    }
    state.elements.arrow = arrowElement;
  }
  var arrow_default = {
    name: "arrow",
    enabled: true,
    phase: "main",
    fn: arrow,
    effect: effect2,
    requires: ["popperOffsets"],
    requiresIfExists: ["preventOverflow"]
  };

  // node_modules/@popperjs/core/lib/utils/getVariation.js
  function getVariation(placement) {
    return placement.split("-")[1];
  }

  // node_modules/@popperjs/core/lib/modifiers/computeStyles.js
  var unsetSides = {
    top: "auto",
    right: "auto",
    bottom: "auto",
    left: "auto"
  };
  function roundOffsetsByDPR(_ref, win) {
    var x = _ref.x, y = _ref.y;
    var dpr = win.devicePixelRatio || 1;
    return {
      x: round(x * dpr) / dpr || 0,
      y: round(y * dpr) / dpr || 0
    };
  }
  function mapToStyles(_ref2) {
    var _Object$assign2;
    var popper2 = _ref2.popper, popperRect = _ref2.popperRect, placement = _ref2.placement, variation = _ref2.variation, offsets = _ref2.offsets, position = _ref2.position, gpuAcceleration = _ref2.gpuAcceleration, adaptive = _ref2.adaptive, roundOffsets = _ref2.roundOffsets, isFixed = _ref2.isFixed;
    var _offsets$x = offsets.x, x = _offsets$x === void 0 ? 0 : _offsets$x, _offsets$y = offsets.y, y = _offsets$y === void 0 ? 0 : _offsets$y;
    var _ref3 = typeof roundOffsets === "function" ? roundOffsets({
      x,
      y
    }) : {
      x,
      y
    };
    x = _ref3.x;
    y = _ref3.y;
    var hasX = offsets.hasOwnProperty("x");
    var hasY = offsets.hasOwnProperty("y");
    var sideX = left;
    var sideY = top;
    var win = window;
    if (adaptive) {
      var offsetParent = getOffsetParent(popper2);
      var heightProp = "clientHeight";
      var widthProp = "clientWidth";
      if (offsetParent === getWindow(popper2)) {
        offsetParent = getDocumentElement(popper2);
        if (getComputedStyle(offsetParent).position !== "static" && position === "absolute") {
          heightProp = "scrollHeight";
          widthProp = "scrollWidth";
        }
      }
      offsetParent = offsetParent;
      if (placement === top || (placement === left || placement === right) && variation === end) {
        sideY = bottom;
        var offsetY = isFixed && offsetParent === win && win.visualViewport ? win.visualViewport.height : (
          // $FlowFixMe[prop-missing]
          offsetParent[heightProp]
        );
        y -= offsetY - popperRect.height;
        y *= gpuAcceleration ? 1 : -1;
      }
      if (placement === left || (placement === top || placement === bottom) && variation === end) {
        sideX = right;
        var offsetX = isFixed && offsetParent === win && win.visualViewport ? win.visualViewport.width : (
          // $FlowFixMe[prop-missing]
          offsetParent[widthProp]
        );
        x -= offsetX - popperRect.width;
        x *= gpuAcceleration ? 1 : -1;
      }
    }
    var commonStyles = Object.assign({
      position
    }, adaptive && unsetSides);
    var _ref4 = roundOffsets === true ? roundOffsetsByDPR({
      x,
      y
    }, getWindow(popper2)) : {
      x,
      y
    };
    x = _ref4.x;
    y = _ref4.y;
    if (gpuAcceleration) {
      var _Object$assign;
      return Object.assign({}, commonStyles, (_Object$assign = {}, _Object$assign[sideY] = hasY ? "0" : "", _Object$assign[sideX] = hasX ? "0" : "", _Object$assign.transform = (win.devicePixelRatio || 1) <= 1 ? "translate(" + x + "px, " + y + "px)" : "translate3d(" + x + "px, " + y + "px, 0)", _Object$assign));
    }
    return Object.assign({}, commonStyles, (_Object$assign2 = {}, _Object$assign2[sideY] = hasY ? y + "px" : "", _Object$assign2[sideX] = hasX ? x + "px" : "", _Object$assign2.transform = "", _Object$assign2));
  }
  function computeStyles(_ref5) {
    var state = _ref5.state, options = _ref5.options;
    var _options$gpuAccelerat = options.gpuAcceleration, gpuAcceleration = _options$gpuAccelerat === void 0 ? true : _options$gpuAccelerat, _options$adaptive = options.adaptive, adaptive = _options$adaptive === void 0 ? true : _options$adaptive, _options$roundOffsets = options.roundOffsets, roundOffsets = _options$roundOffsets === void 0 ? true : _options$roundOffsets;
    var commonStyles = {
      placement: getBasePlacement(state.placement),
      variation: getVariation(state.placement),
      popper: state.elements.popper,
      popperRect: state.rects.popper,
      gpuAcceleration,
      isFixed: state.options.strategy === "fixed"
    };
    if (state.modifiersData.popperOffsets != null) {
      state.styles.popper = Object.assign({}, state.styles.popper, mapToStyles(Object.assign({}, commonStyles, {
        offsets: state.modifiersData.popperOffsets,
        position: state.options.strategy,
        adaptive,
        roundOffsets
      })));
    }
    if (state.modifiersData.arrow != null) {
      state.styles.arrow = Object.assign({}, state.styles.arrow, mapToStyles(Object.assign({}, commonStyles, {
        offsets: state.modifiersData.arrow,
        position: "absolute",
        adaptive: false,
        roundOffsets
      })));
    }
    state.attributes.popper = Object.assign({}, state.attributes.popper, {
      "data-popper-placement": state.placement
    });
  }
  var computeStyles_default = {
    name: "computeStyles",
    enabled: true,
    phase: "beforeWrite",
    fn: computeStyles,
    data: {}
  };

  // node_modules/@popperjs/core/lib/modifiers/eventListeners.js
  var passive = {
    passive: true
  };
  function effect3(_ref) {
    var state = _ref.state, instance = _ref.instance, options = _ref.options;
    var _options$scroll = options.scroll, scroll = _options$scroll === void 0 ? true : _options$scroll, _options$resize = options.resize, resize = _options$resize === void 0 ? true : _options$resize;
    var window2 = getWindow(state.elements.popper);
    var scrollParents = [].concat(state.scrollParents.reference, state.scrollParents.popper);
    if (scroll) {
      scrollParents.forEach(function(scrollParent) {
        scrollParent.addEventListener("scroll", instance.update, passive);
      });
    }
    if (resize) {
      window2.addEventListener("resize", instance.update, passive);
    }
    return function() {
      if (scroll) {
        scrollParents.forEach(function(scrollParent) {
          scrollParent.removeEventListener("scroll", instance.update, passive);
        });
      }
      if (resize) {
        window2.removeEventListener("resize", instance.update, passive);
      }
    };
  }
  var eventListeners_default = {
    name: "eventListeners",
    enabled: true,
    phase: "write",
    fn: function fn() {
    },
    effect: effect3,
    data: {}
  };

  // node_modules/@popperjs/core/lib/utils/getOppositePlacement.js
  var hash = {
    left: "right",
    right: "left",
    bottom: "top",
    top: "bottom"
  };
  function getOppositePlacement(placement) {
    return placement.replace(/left|right|bottom|top/g, function(matched) {
      return hash[matched];
    });
  }

  // node_modules/@popperjs/core/lib/utils/getOppositeVariationPlacement.js
  var hash2 = {
    start: "end",
    end: "start"
  };
  function getOppositeVariationPlacement(placement) {
    return placement.replace(/start|end/g, function(matched) {
      return hash2[matched];
    });
  }

  // node_modules/@popperjs/core/lib/dom-utils/getWindowScroll.js
  function getWindowScroll(node) {
    var win = getWindow(node);
    var scrollLeft = win.pageXOffset;
    var scrollTop = win.pageYOffset;
    return {
      scrollLeft,
      scrollTop
    };
  }

  // node_modules/@popperjs/core/lib/dom-utils/getWindowScrollBarX.js
  function getWindowScrollBarX(element) {
    return getBoundingClientRect(getDocumentElement(element)).left + getWindowScroll(element).scrollLeft;
  }

  // node_modules/@popperjs/core/lib/dom-utils/getViewportRect.js
  function getViewportRect(element, strategy) {
    var win = getWindow(element);
    var html = getDocumentElement(element);
    var visualViewport = win.visualViewport;
    var width = html.clientWidth;
    var height = html.clientHeight;
    var x = 0;
    var y = 0;
    if (visualViewport) {
      width = visualViewport.width;
      height = visualViewport.height;
      var layoutViewport = isLayoutViewport();
      if (layoutViewport || !layoutViewport && strategy === "fixed") {
        x = visualViewport.offsetLeft;
        y = visualViewport.offsetTop;
      }
    }
    return {
      width,
      height,
      x: x + getWindowScrollBarX(element),
      y
    };
  }

  // node_modules/@popperjs/core/lib/dom-utils/getDocumentRect.js
  function getDocumentRect(element) {
    var _element$ownerDocumen;
    var html = getDocumentElement(element);
    var winScroll = getWindowScroll(element);
    var body = (_element$ownerDocumen = element.ownerDocument) == null ? void 0 : _element$ownerDocumen.body;
    var width = max(html.scrollWidth, html.clientWidth, body ? body.scrollWidth : 0, body ? body.clientWidth : 0);
    var height = max(html.scrollHeight, html.clientHeight, body ? body.scrollHeight : 0, body ? body.clientHeight : 0);
    var x = -winScroll.scrollLeft + getWindowScrollBarX(element);
    var y = -winScroll.scrollTop;
    if (getComputedStyle(body || html).direction === "rtl") {
      x += max(html.clientWidth, body ? body.clientWidth : 0) - width;
    }
    return {
      width,
      height,
      x,
      y
    };
  }

  // node_modules/@popperjs/core/lib/dom-utils/isScrollParent.js
  function isScrollParent(element) {
    var _getComputedStyle = getComputedStyle(element), overflow = _getComputedStyle.overflow, overflowX = _getComputedStyle.overflowX, overflowY = _getComputedStyle.overflowY;
    return /auto|scroll|overlay|hidden/.test(overflow + overflowY + overflowX);
  }

  // node_modules/@popperjs/core/lib/dom-utils/getScrollParent.js
  function getScrollParent(node) {
    if (["html", "body", "#document"].indexOf(getNodeName(node)) >= 0) {
      return node.ownerDocument.body;
    }
    if (isHTMLElement(node) && isScrollParent(node)) {
      return node;
    }
    return getScrollParent(getParentNode(node));
  }

  // node_modules/@popperjs/core/lib/dom-utils/listScrollParents.js
  function listScrollParents(element, list) {
    var _element$ownerDocumen;
    if (list === void 0) {
      list = [];
    }
    var scrollParent = getScrollParent(element);
    var isBody = scrollParent === ((_element$ownerDocumen = element.ownerDocument) == null ? void 0 : _element$ownerDocumen.body);
    var win = getWindow(scrollParent);
    var target = isBody ? [win].concat(win.visualViewport || [], isScrollParent(scrollParent) ? scrollParent : []) : scrollParent;
    var updatedList = list.concat(target);
    return isBody ? updatedList : (
      // $FlowFixMe[incompatible-call]: isBody tells us target will be an HTMLElement here
      updatedList.concat(listScrollParents(getParentNode(target)))
    );
  }

  // node_modules/@popperjs/core/lib/utils/rectToClientRect.js
  function rectToClientRect(rect) {
    return Object.assign({}, rect, {
      left: rect.x,
      top: rect.y,
      right: rect.x + rect.width,
      bottom: rect.y + rect.height
    });
  }

  // node_modules/@popperjs/core/lib/dom-utils/getClippingRect.js
  function getInnerBoundingClientRect(element, strategy) {
    var rect = getBoundingClientRect(element, false, strategy === "fixed");
    rect.top = rect.top + element.clientTop;
    rect.left = rect.left + element.clientLeft;
    rect.bottom = rect.top + element.clientHeight;
    rect.right = rect.left + element.clientWidth;
    rect.width = element.clientWidth;
    rect.height = element.clientHeight;
    rect.x = rect.left;
    rect.y = rect.top;
    return rect;
  }
  function getClientRectFromMixedType(element, clippingParent, strategy) {
    return clippingParent === viewport ? rectToClientRect(getViewportRect(element, strategy)) : isElement(clippingParent) ? getInnerBoundingClientRect(clippingParent, strategy) : rectToClientRect(getDocumentRect(getDocumentElement(element)));
  }
  function getClippingParents(element) {
    var clippingParents2 = listScrollParents(getParentNode(element));
    var canEscapeClipping = ["absolute", "fixed"].indexOf(getComputedStyle(element).position) >= 0;
    var clipperElement = canEscapeClipping && isHTMLElement(element) ? getOffsetParent(element) : element;
    if (!isElement(clipperElement)) {
      return [];
    }
    return clippingParents2.filter(function(clippingParent) {
      return isElement(clippingParent) && contains(clippingParent, clipperElement) && getNodeName(clippingParent) !== "body";
    });
  }
  function getClippingRect(element, boundary, rootBoundary, strategy) {
    var mainClippingParents = boundary === "clippingParents" ? getClippingParents(element) : [].concat(boundary);
    var clippingParents2 = [].concat(mainClippingParents, [rootBoundary]);
    var firstClippingParent = clippingParents2[0];
    var clippingRect = clippingParents2.reduce(function(accRect, clippingParent) {
      var rect = getClientRectFromMixedType(element, clippingParent, strategy);
      accRect.top = max(rect.top, accRect.top);
      accRect.right = min(rect.right, accRect.right);
      accRect.bottom = min(rect.bottom, accRect.bottom);
      accRect.left = max(rect.left, accRect.left);
      return accRect;
    }, getClientRectFromMixedType(element, firstClippingParent, strategy));
    clippingRect.width = clippingRect.right - clippingRect.left;
    clippingRect.height = clippingRect.bottom - clippingRect.top;
    clippingRect.x = clippingRect.left;
    clippingRect.y = clippingRect.top;
    return clippingRect;
  }

  // node_modules/@popperjs/core/lib/utils/computeOffsets.js
  function computeOffsets(_ref) {
    var reference2 = _ref.reference, element = _ref.element, placement = _ref.placement;
    var basePlacement = placement ? getBasePlacement(placement) : null;
    var variation = placement ? getVariation(placement) : null;
    var commonX = reference2.x + reference2.width / 2 - element.width / 2;
    var commonY = reference2.y + reference2.height / 2 - element.height / 2;
    var offsets;
    switch (basePlacement) {
      case top:
        offsets = {
          x: commonX,
          y: reference2.y - element.height
        };
        break;
      case bottom:
        offsets = {
          x: commonX,
          y: reference2.y + reference2.height
        };
        break;
      case right:
        offsets = {
          x: reference2.x + reference2.width,
          y: commonY
        };
        break;
      case left:
        offsets = {
          x: reference2.x - element.width,
          y: commonY
        };
        break;
      default:
        offsets = {
          x: reference2.x,
          y: reference2.y
        };
    }
    var mainAxis = basePlacement ? getMainAxisFromPlacement(basePlacement) : null;
    if (mainAxis != null) {
      var len = mainAxis === "y" ? "height" : "width";
      switch (variation) {
        case start:
          offsets[mainAxis] = offsets[mainAxis] - (reference2[len] / 2 - element[len] / 2);
          break;
        case end:
          offsets[mainAxis] = offsets[mainAxis] + (reference2[len] / 2 - element[len] / 2);
          break;
        default:
      }
    }
    return offsets;
  }

  // node_modules/@popperjs/core/lib/utils/detectOverflow.js
  function detectOverflow(state, options) {
    if (options === void 0) {
      options = {};
    }
    var _options = options, _options$placement = _options.placement, placement = _options$placement === void 0 ? state.placement : _options$placement, _options$strategy = _options.strategy, strategy = _options$strategy === void 0 ? state.strategy : _options$strategy, _options$boundary = _options.boundary, boundary = _options$boundary === void 0 ? clippingParents : _options$boundary, _options$rootBoundary = _options.rootBoundary, rootBoundary = _options$rootBoundary === void 0 ? viewport : _options$rootBoundary, _options$elementConte = _options.elementContext, elementContext = _options$elementConte === void 0 ? popper : _options$elementConte, _options$altBoundary = _options.altBoundary, altBoundary = _options$altBoundary === void 0 ? false : _options$altBoundary, _options$padding = _options.padding, padding = _options$padding === void 0 ? 0 : _options$padding;
    var paddingObject = mergePaddingObject(typeof padding !== "number" ? padding : expandToHashMap(padding, basePlacements));
    var altContext = elementContext === popper ? reference : popper;
    var popperRect = state.rects.popper;
    var element = state.elements[altBoundary ? altContext : elementContext];
    var clippingClientRect = getClippingRect(isElement(element) ? element : element.contextElement || getDocumentElement(state.elements.popper), boundary, rootBoundary, strategy);
    var referenceClientRect = getBoundingClientRect(state.elements.reference);
    var popperOffsets2 = computeOffsets({
      reference: referenceClientRect,
      element: popperRect,
      strategy: "absolute",
      placement
    });
    var popperClientRect = rectToClientRect(Object.assign({}, popperRect, popperOffsets2));
    var elementClientRect = elementContext === popper ? popperClientRect : referenceClientRect;
    var overflowOffsets = {
      top: clippingClientRect.top - elementClientRect.top + paddingObject.top,
      bottom: elementClientRect.bottom - clippingClientRect.bottom + paddingObject.bottom,
      left: clippingClientRect.left - elementClientRect.left + paddingObject.left,
      right: elementClientRect.right - clippingClientRect.right + paddingObject.right
    };
    var offsetData = state.modifiersData.offset;
    if (elementContext === popper && offsetData) {
      var offset2 = offsetData[placement];
      Object.keys(overflowOffsets).forEach(function(key) {
        var multiply = [right, bottom].indexOf(key) >= 0 ? 1 : -1;
        var axis = [top, bottom].indexOf(key) >= 0 ? "y" : "x";
        overflowOffsets[key] += offset2[axis] * multiply;
      });
    }
    return overflowOffsets;
  }

  // node_modules/@popperjs/core/lib/utils/computeAutoPlacement.js
  function computeAutoPlacement(state, options) {
    if (options === void 0) {
      options = {};
    }
    var _options = options, placement = _options.placement, boundary = _options.boundary, rootBoundary = _options.rootBoundary, padding = _options.padding, flipVariations = _options.flipVariations, _options$allowedAutoP = _options.allowedAutoPlacements, allowedAutoPlacements = _options$allowedAutoP === void 0 ? placements : _options$allowedAutoP;
    var variation = getVariation(placement);
    var placements2 = variation ? flipVariations ? variationPlacements : variationPlacements.filter(function(placement2) {
      return getVariation(placement2) === variation;
    }) : basePlacements;
    var allowedPlacements = placements2.filter(function(placement2) {
      return allowedAutoPlacements.indexOf(placement2) >= 0;
    });
    if (allowedPlacements.length === 0) {
      allowedPlacements = placements2;
    }
    var overflows = allowedPlacements.reduce(function(acc, placement2) {
      acc[placement2] = detectOverflow(state, {
        placement: placement2,
        boundary,
        rootBoundary,
        padding
      })[getBasePlacement(placement2)];
      return acc;
    }, {});
    return Object.keys(overflows).sort(function(a, b) {
      return overflows[a] - overflows[b];
    });
  }

  // node_modules/@popperjs/core/lib/modifiers/flip.js
  function getExpandedFallbackPlacements(placement) {
    if (getBasePlacement(placement) === auto) {
      return [];
    }
    var oppositePlacement = getOppositePlacement(placement);
    return [getOppositeVariationPlacement(placement), oppositePlacement, getOppositeVariationPlacement(oppositePlacement)];
  }
  function flip(_ref) {
    var state = _ref.state, options = _ref.options, name = _ref.name;
    if (state.modifiersData[name]._skip) {
      return;
    }
    var _options$mainAxis = options.mainAxis, checkMainAxis = _options$mainAxis === void 0 ? true : _options$mainAxis, _options$altAxis = options.altAxis, checkAltAxis = _options$altAxis === void 0 ? true : _options$altAxis, specifiedFallbackPlacements = options.fallbackPlacements, padding = options.padding, boundary = options.boundary, rootBoundary = options.rootBoundary, altBoundary = options.altBoundary, _options$flipVariatio = options.flipVariations, flipVariations = _options$flipVariatio === void 0 ? true : _options$flipVariatio, allowedAutoPlacements = options.allowedAutoPlacements;
    var preferredPlacement = state.options.placement;
    var basePlacement = getBasePlacement(preferredPlacement);
    var isBasePlacement = basePlacement === preferredPlacement;
    var fallbackPlacements = specifiedFallbackPlacements || (isBasePlacement || !flipVariations ? [getOppositePlacement(preferredPlacement)] : getExpandedFallbackPlacements(preferredPlacement));
    var placements2 = [preferredPlacement].concat(fallbackPlacements).reduce(function(acc, placement2) {
      return acc.concat(getBasePlacement(placement2) === auto ? computeAutoPlacement(state, {
        placement: placement2,
        boundary,
        rootBoundary,
        padding,
        flipVariations,
        allowedAutoPlacements
      }) : placement2);
    }, []);
    var referenceRect = state.rects.reference;
    var popperRect = state.rects.popper;
    var checksMap = /* @__PURE__ */ new Map();
    var makeFallbackChecks = true;
    var firstFittingPlacement = placements2[0];
    for (var i = 0; i < placements2.length; i++) {
      var placement = placements2[i];
      var _basePlacement = getBasePlacement(placement);
      var isStartVariation = getVariation(placement) === start;
      var isVertical = [top, bottom].indexOf(_basePlacement) >= 0;
      var len = isVertical ? "width" : "height";
      var overflow = detectOverflow(state, {
        placement,
        boundary,
        rootBoundary,
        altBoundary,
        padding
      });
      var mainVariationSide = isVertical ? isStartVariation ? right : left : isStartVariation ? bottom : top;
      if (referenceRect[len] > popperRect[len]) {
        mainVariationSide = getOppositePlacement(mainVariationSide);
      }
      var altVariationSide = getOppositePlacement(mainVariationSide);
      var checks = [];
      if (checkMainAxis) {
        checks.push(overflow[_basePlacement] <= 0);
      }
      if (checkAltAxis) {
        checks.push(overflow[mainVariationSide] <= 0, overflow[altVariationSide] <= 0);
      }
      if (checks.every(function(check) {
        return check;
      })) {
        firstFittingPlacement = placement;
        makeFallbackChecks = false;
        break;
      }
      checksMap.set(placement, checks);
    }
    if (makeFallbackChecks) {
      var numberOfChecks = flipVariations ? 3 : 1;
      var _loop = function _loop2(_i2) {
        var fittingPlacement = placements2.find(function(placement2) {
          var checks2 = checksMap.get(placement2);
          if (checks2) {
            return checks2.slice(0, _i2).every(function(check) {
              return check;
            });
          }
        });
        if (fittingPlacement) {
          firstFittingPlacement = fittingPlacement;
          return "break";
        }
      };
      for (var _i = numberOfChecks; _i > 0; _i--) {
        var _ret = _loop(_i);
        if (_ret === "break")
          break;
      }
    }
    if (state.placement !== firstFittingPlacement) {
      state.modifiersData[name]._skip = true;
      state.placement = firstFittingPlacement;
      state.reset = true;
    }
  }
  var flip_default = {
    name: "flip",
    enabled: true,
    phase: "main",
    fn: flip,
    requiresIfExists: ["offset"],
    data: {
      _skip: false
    }
  };

  // node_modules/@popperjs/core/lib/modifiers/hide.js
  function getSideOffsets(overflow, rect, preventedOffsets) {
    if (preventedOffsets === void 0) {
      preventedOffsets = {
        x: 0,
        y: 0
      };
    }
    return {
      top: overflow.top - rect.height - preventedOffsets.y,
      right: overflow.right - rect.width + preventedOffsets.x,
      bottom: overflow.bottom - rect.height + preventedOffsets.y,
      left: overflow.left - rect.width - preventedOffsets.x
    };
  }
  function isAnySideFullyClipped(overflow) {
    return [top, right, bottom, left].some(function(side) {
      return overflow[side] >= 0;
    });
  }
  function hide(_ref) {
    var state = _ref.state, name = _ref.name;
    var referenceRect = state.rects.reference;
    var popperRect = state.rects.popper;
    var preventedOffsets = state.modifiersData.preventOverflow;
    var referenceOverflow = detectOverflow(state, {
      elementContext: "reference"
    });
    var popperAltOverflow = detectOverflow(state, {
      altBoundary: true
    });
    var referenceClippingOffsets = getSideOffsets(referenceOverflow, referenceRect);
    var popperEscapeOffsets = getSideOffsets(popperAltOverflow, popperRect, preventedOffsets);
    var isReferenceHidden = isAnySideFullyClipped(referenceClippingOffsets);
    var hasPopperEscaped = isAnySideFullyClipped(popperEscapeOffsets);
    state.modifiersData[name] = {
      referenceClippingOffsets,
      popperEscapeOffsets,
      isReferenceHidden,
      hasPopperEscaped
    };
    state.attributes.popper = Object.assign({}, state.attributes.popper, {
      "data-popper-reference-hidden": isReferenceHidden,
      "data-popper-escaped": hasPopperEscaped
    });
  }
  var hide_default = {
    name: "hide",
    enabled: true,
    phase: "main",
    requiresIfExists: ["preventOverflow"],
    fn: hide
  };

  // node_modules/@popperjs/core/lib/modifiers/offset.js
  function distanceAndSkiddingToXY(placement, rects, offset2) {
    var basePlacement = getBasePlacement(placement);
    var invertDistance = [left, top].indexOf(basePlacement) >= 0 ? -1 : 1;
    var _ref = typeof offset2 === "function" ? offset2(Object.assign({}, rects, {
      placement
    })) : offset2, skidding = _ref[0], distance = _ref[1];
    skidding = skidding || 0;
    distance = (distance || 0) * invertDistance;
    return [left, right].indexOf(basePlacement) >= 0 ? {
      x: distance,
      y: skidding
    } : {
      x: skidding,
      y: distance
    };
  }
  function offset(_ref2) {
    var state = _ref2.state, options = _ref2.options, name = _ref2.name;
    var _options$offset = options.offset, offset2 = _options$offset === void 0 ? [0, 0] : _options$offset;
    var data = placements.reduce(function(acc, placement) {
      acc[placement] = distanceAndSkiddingToXY(placement, state.rects, offset2);
      return acc;
    }, {});
    var _data$state$placement = data[state.placement], x = _data$state$placement.x, y = _data$state$placement.y;
    if (state.modifiersData.popperOffsets != null) {
      state.modifiersData.popperOffsets.x += x;
      state.modifiersData.popperOffsets.y += y;
    }
    state.modifiersData[name] = data;
  }
  var offset_default = {
    name: "offset",
    enabled: true,
    phase: "main",
    requires: ["popperOffsets"],
    fn: offset
  };

  // node_modules/@popperjs/core/lib/modifiers/popperOffsets.js
  function popperOffsets(_ref) {
    var state = _ref.state, name = _ref.name;
    state.modifiersData[name] = computeOffsets({
      reference: state.rects.reference,
      element: state.rects.popper,
      strategy: "absolute",
      placement: state.placement
    });
  }
  var popperOffsets_default = {
    name: "popperOffsets",
    enabled: true,
    phase: "read",
    fn: popperOffsets,
    data: {}
  };

  // node_modules/@popperjs/core/lib/utils/getAltAxis.js
  function getAltAxis(axis) {
    return axis === "x" ? "y" : "x";
  }

  // node_modules/@popperjs/core/lib/modifiers/preventOverflow.js
  function preventOverflow(_ref) {
    var state = _ref.state, options = _ref.options, name = _ref.name;
    var _options$mainAxis = options.mainAxis, checkMainAxis = _options$mainAxis === void 0 ? true : _options$mainAxis, _options$altAxis = options.altAxis, checkAltAxis = _options$altAxis === void 0 ? false : _options$altAxis, boundary = options.boundary, rootBoundary = options.rootBoundary, altBoundary = options.altBoundary, padding = options.padding, _options$tether = options.tether, tether = _options$tether === void 0 ? true : _options$tether, _options$tetherOffset = options.tetherOffset, tetherOffset = _options$tetherOffset === void 0 ? 0 : _options$tetherOffset;
    var overflow = detectOverflow(state, {
      boundary,
      rootBoundary,
      padding,
      altBoundary
    });
    var basePlacement = getBasePlacement(state.placement);
    var variation = getVariation(state.placement);
    var isBasePlacement = !variation;
    var mainAxis = getMainAxisFromPlacement(basePlacement);
    var altAxis = getAltAxis(mainAxis);
    var popperOffsets2 = state.modifiersData.popperOffsets;
    var referenceRect = state.rects.reference;
    var popperRect = state.rects.popper;
    var tetherOffsetValue = typeof tetherOffset === "function" ? tetherOffset(Object.assign({}, state.rects, {
      placement: state.placement
    })) : tetherOffset;
    var normalizedTetherOffsetValue = typeof tetherOffsetValue === "number" ? {
      mainAxis: tetherOffsetValue,
      altAxis: tetherOffsetValue
    } : Object.assign({
      mainAxis: 0,
      altAxis: 0
    }, tetherOffsetValue);
    var offsetModifierState = state.modifiersData.offset ? state.modifiersData.offset[state.placement] : null;
    var data = {
      x: 0,
      y: 0
    };
    if (!popperOffsets2) {
      return;
    }
    if (checkMainAxis) {
      var _offsetModifierState$;
      var mainSide = mainAxis === "y" ? top : left;
      var altSide = mainAxis === "y" ? bottom : right;
      var len = mainAxis === "y" ? "height" : "width";
      var offset2 = popperOffsets2[mainAxis];
      var min2 = offset2 + overflow[mainSide];
      var max2 = offset2 - overflow[altSide];
      var additive = tether ? -popperRect[len] / 2 : 0;
      var minLen = variation === start ? referenceRect[len] : popperRect[len];
      var maxLen = variation === start ? -popperRect[len] : -referenceRect[len];
      var arrowElement = state.elements.arrow;
      var arrowRect = tether && arrowElement ? getLayoutRect(arrowElement) : {
        width: 0,
        height: 0
      };
      var arrowPaddingObject = state.modifiersData["arrow#persistent"] ? state.modifiersData["arrow#persistent"].padding : getFreshSideObject();
      var arrowPaddingMin = arrowPaddingObject[mainSide];
      var arrowPaddingMax = arrowPaddingObject[altSide];
      var arrowLen = within(0, referenceRect[len], arrowRect[len]);
      var minOffset = isBasePlacement ? referenceRect[len] / 2 - additive - arrowLen - arrowPaddingMin - normalizedTetherOffsetValue.mainAxis : minLen - arrowLen - arrowPaddingMin - normalizedTetherOffsetValue.mainAxis;
      var maxOffset = isBasePlacement ? -referenceRect[len] / 2 + additive + arrowLen + arrowPaddingMax + normalizedTetherOffsetValue.mainAxis : maxLen + arrowLen + arrowPaddingMax + normalizedTetherOffsetValue.mainAxis;
      var arrowOffsetParent = state.elements.arrow && getOffsetParent(state.elements.arrow);
      var clientOffset = arrowOffsetParent ? mainAxis === "y" ? arrowOffsetParent.clientTop || 0 : arrowOffsetParent.clientLeft || 0 : 0;
      var offsetModifierValue = (_offsetModifierState$ = offsetModifierState == null ? void 0 : offsetModifierState[mainAxis]) != null ? _offsetModifierState$ : 0;
      var tetherMin = offset2 + minOffset - offsetModifierValue - clientOffset;
      var tetherMax = offset2 + maxOffset - offsetModifierValue;
      var preventedOffset = within(tether ? min(min2, tetherMin) : min2, offset2, tether ? max(max2, tetherMax) : max2);
      popperOffsets2[mainAxis] = preventedOffset;
      data[mainAxis] = preventedOffset - offset2;
    }
    if (checkAltAxis) {
      var _offsetModifierState$2;
      var _mainSide = mainAxis === "x" ? top : left;
      var _altSide = mainAxis === "x" ? bottom : right;
      var _offset = popperOffsets2[altAxis];
      var _len = altAxis === "y" ? "height" : "width";
      var _min = _offset + overflow[_mainSide];
      var _max = _offset - overflow[_altSide];
      var isOriginSide = [top, left].indexOf(basePlacement) !== -1;
      var _offsetModifierValue = (_offsetModifierState$2 = offsetModifierState == null ? void 0 : offsetModifierState[altAxis]) != null ? _offsetModifierState$2 : 0;
      var _tetherMin = isOriginSide ? _min : _offset - referenceRect[_len] - popperRect[_len] - _offsetModifierValue + normalizedTetherOffsetValue.altAxis;
      var _tetherMax = isOriginSide ? _offset + referenceRect[_len] + popperRect[_len] - _offsetModifierValue - normalizedTetherOffsetValue.altAxis : _max;
      var _preventedOffset = tether && isOriginSide ? withinMaxClamp(_tetherMin, _offset, _tetherMax) : within(tether ? _tetherMin : _min, _offset, tether ? _tetherMax : _max);
      popperOffsets2[altAxis] = _preventedOffset;
      data[altAxis] = _preventedOffset - _offset;
    }
    state.modifiersData[name] = data;
  }
  var preventOverflow_default = {
    name: "preventOverflow",
    enabled: true,
    phase: "main",
    fn: preventOverflow,
    requiresIfExists: ["offset"]
  };

  // node_modules/@popperjs/core/lib/dom-utils/getHTMLElementScroll.js
  function getHTMLElementScroll(element) {
    return {
      scrollLeft: element.scrollLeft,
      scrollTop: element.scrollTop
    };
  }

  // node_modules/@popperjs/core/lib/dom-utils/getNodeScroll.js
  function getNodeScroll(node) {
    if (node === getWindow(node) || !isHTMLElement(node)) {
      return getWindowScroll(node);
    } else {
      return getHTMLElementScroll(node);
    }
  }

  // node_modules/@popperjs/core/lib/dom-utils/getCompositeRect.js
  function isElementScaled(element) {
    var rect = element.getBoundingClientRect();
    var scaleX = round(rect.width) / element.offsetWidth || 1;
    var scaleY = round(rect.height) / element.offsetHeight || 1;
    return scaleX !== 1 || scaleY !== 1;
  }
  function getCompositeRect(elementOrVirtualElement, offsetParent, isFixed) {
    if (isFixed === void 0) {
      isFixed = false;
    }
    var isOffsetParentAnElement = isHTMLElement(offsetParent);
    var offsetParentIsScaled = isHTMLElement(offsetParent) && isElementScaled(offsetParent);
    var documentElement = getDocumentElement(offsetParent);
    var rect = getBoundingClientRect(elementOrVirtualElement, offsetParentIsScaled, isFixed);
    var scroll = {
      scrollLeft: 0,
      scrollTop: 0
    };
    var offsets = {
      x: 0,
      y: 0
    };
    if (isOffsetParentAnElement || !isOffsetParentAnElement && !isFixed) {
      if (getNodeName(offsetParent) !== "body" || // https://github.com/popperjs/popper-core/issues/1078
      isScrollParent(documentElement)) {
        scroll = getNodeScroll(offsetParent);
      }
      if (isHTMLElement(offsetParent)) {
        offsets = getBoundingClientRect(offsetParent, true);
        offsets.x += offsetParent.clientLeft;
        offsets.y += offsetParent.clientTop;
      } else if (documentElement) {
        offsets.x = getWindowScrollBarX(documentElement);
      }
    }
    return {
      x: rect.left + scroll.scrollLeft - offsets.x,
      y: rect.top + scroll.scrollTop - offsets.y,
      width: rect.width,
      height: rect.height
    };
  }

  // node_modules/@popperjs/core/lib/utils/orderModifiers.js
  function order(modifiers) {
    var map = /* @__PURE__ */ new Map();
    var visited = /* @__PURE__ */ new Set();
    var result = [];
    modifiers.forEach(function(modifier) {
      map.set(modifier.name, modifier);
    });
    function sort(modifier) {
      visited.add(modifier.name);
      var requires = [].concat(modifier.requires || [], modifier.requiresIfExists || []);
      requires.forEach(function(dep) {
        if (!visited.has(dep)) {
          var depModifier = map.get(dep);
          if (depModifier) {
            sort(depModifier);
          }
        }
      });
      result.push(modifier);
    }
    modifiers.forEach(function(modifier) {
      if (!visited.has(modifier.name)) {
        sort(modifier);
      }
    });
    return result;
  }
  function orderModifiers(modifiers) {
    var orderedModifiers = order(modifiers);
    return modifierPhases.reduce(function(acc, phase) {
      return acc.concat(orderedModifiers.filter(function(modifier) {
        return modifier.phase === phase;
      }));
    }, []);
  }

  // node_modules/@popperjs/core/lib/utils/debounce.js
  function debounce2(fn2) {
    var pending;
    return function() {
      if (!pending) {
        pending = new Promise(function(resolve) {
          Promise.resolve().then(function() {
            pending = void 0;
            resolve(fn2());
          });
        });
      }
      return pending;
    };
  }

  // node_modules/@popperjs/core/lib/utils/mergeByName.js
  function mergeByName(modifiers) {
    var merged = modifiers.reduce(function(merged2, current) {
      var existing = merged2[current.name];
      merged2[current.name] = existing ? Object.assign({}, existing, current, {
        options: Object.assign({}, existing.options, current.options),
        data: Object.assign({}, existing.data, current.data)
      }) : current;
      return merged2;
    }, {});
    return Object.keys(merged).map(function(key) {
      return merged[key];
    });
  }

  // node_modules/@popperjs/core/lib/createPopper.js
  var DEFAULT_OPTIONS = {
    placement: "bottom",
    modifiers: [],
    strategy: "absolute"
  };
  function areValidElements() {
    for (var _len = arguments.length, args = new Array(_len), _key = 0; _key < _len; _key++) {
      args[_key] = arguments[_key];
    }
    return !args.some(function(element) {
      return !(element && typeof element.getBoundingClientRect === "function");
    });
  }
  function popperGenerator(generatorOptions) {
    if (generatorOptions === void 0) {
      generatorOptions = {};
    }
    var _generatorOptions = generatorOptions, _generatorOptions$def = _generatorOptions.defaultModifiers, defaultModifiers2 = _generatorOptions$def === void 0 ? [] : _generatorOptions$def, _generatorOptions$def2 = _generatorOptions.defaultOptions, defaultOptions = _generatorOptions$def2 === void 0 ? DEFAULT_OPTIONS : _generatorOptions$def2;
    return function createPopper2(reference2, popper2, options) {
      if (options === void 0) {
        options = defaultOptions;
      }
      var state = {
        placement: "bottom",
        orderedModifiers: [],
        options: Object.assign({}, DEFAULT_OPTIONS, defaultOptions),
        modifiersData: {},
        elements: {
          reference: reference2,
          popper: popper2
        },
        attributes: {},
        styles: {}
      };
      var effectCleanupFns = [];
      var isDestroyed = false;
      var instance = {
        state,
        setOptions: function setOptions(setOptionsAction) {
          var options2 = typeof setOptionsAction === "function" ? setOptionsAction(state.options) : setOptionsAction;
          cleanupModifierEffects();
          state.options = Object.assign({}, defaultOptions, state.options, options2);
          state.scrollParents = {
            reference: isElement(reference2) ? listScrollParents(reference2) : reference2.contextElement ? listScrollParents(reference2.contextElement) : [],
            popper: listScrollParents(popper2)
          };
          var orderedModifiers = orderModifiers(mergeByName([].concat(defaultModifiers2, state.options.modifiers)));
          state.orderedModifiers = orderedModifiers.filter(function(m) {
            return m.enabled;
          });
          runModifierEffects();
          return instance.update();
        },
        // Sync update – it will always be executed, even if not necessary. This
        // is useful for low frequency updates where sync behavior simplifies the
        // logic.
        // For high frequency updates (e.g. `resize` and `scroll` events), always
        // prefer the async Popper#update method
        forceUpdate: function forceUpdate() {
          if (isDestroyed) {
            return;
          }
          var _state$elements = state.elements, reference3 = _state$elements.reference, popper3 = _state$elements.popper;
          if (!areValidElements(reference3, popper3)) {
            return;
          }
          state.rects = {
            reference: getCompositeRect(reference3, getOffsetParent(popper3), state.options.strategy === "fixed"),
            popper: getLayoutRect(popper3)
          };
          state.reset = false;
          state.placement = state.options.placement;
          state.orderedModifiers.forEach(function(modifier) {
            return state.modifiersData[modifier.name] = Object.assign({}, modifier.data);
          });
          for (var index = 0; index < state.orderedModifiers.length; index++) {
            if (state.reset === true) {
              state.reset = false;
              index = -1;
              continue;
            }
            var _state$orderedModifie = state.orderedModifiers[index], fn2 = _state$orderedModifie.fn, _state$orderedModifie2 = _state$orderedModifie.options, _options = _state$orderedModifie2 === void 0 ? {} : _state$orderedModifie2, name = _state$orderedModifie.name;
            if (typeof fn2 === "function") {
              state = fn2({
                state,
                options: _options,
                name,
                instance
              }) || state;
            }
          }
        },
        // Async and optimistically optimized update – it will not be executed if
        // not necessary (debounced to run at most once-per-tick)
        update: debounce2(function() {
          return new Promise(function(resolve) {
            instance.forceUpdate();
            resolve(state);
          });
        }),
        destroy: function destroy() {
          cleanupModifierEffects();
          isDestroyed = true;
        }
      };
      if (!areValidElements(reference2, popper2)) {
        return instance;
      }
      instance.setOptions(options).then(function(state2) {
        if (!isDestroyed && options.onFirstUpdate) {
          options.onFirstUpdate(state2);
        }
      });
      function runModifierEffects() {
        state.orderedModifiers.forEach(function(_ref) {
          var name = _ref.name, _ref$options = _ref.options, options2 = _ref$options === void 0 ? {} : _ref$options, effect4 = _ref.effect;
          if (typeof effect4 === "function") {
            var cleanupFn = effect4({
              state,
              name,
              instance,
              options: options2
            });
            var noopFn = function noopFn2() {
            };
            effectCleanupFns.push(cleanupFn || noopFn);
          }
        });
      }
      function cleanupModifierEffects() {
        effectCleanupFns.forEach(function(fn2) {
          return fn2();
        });
        effectCleanupFns = [];
      }
      return instance;
    };
  }

  // node_modules/@popperjs/core/lib/popper.js
  var defaultModifiers = [eventListeners_default, popperOffsets_default, computeStyles_default, applyStyles_default, offset_default, flip_default, preventOverflow_default, arrow_default, hide_default];
  var createPopper = /* @__PURE__ */ popperGenerator({
    defaultModifiers
  });

  // node_modules/flowbite/lib/esm/components/dropdown/index.js
  var __assign5 = function() {
    __assign5 = Object.assign || function(t) {
      for (var s, i = 1, n = arguments.length; i < n; i++) {
        s = arguments[i];
        for (var p in s)
          if (Object.prototype.hasOwnProperty.call(s, p))
            t[p] = s[p];
      }
      return t;
    };
    return __assign5.apply(this, arguments);
  };
  var __spreadArray = function(to, from, pack) {
    if (pack || arguments.length === 2)
      for (var i = 0, l = from.length, ar; i < l; i++) {
        if (ar || !(i in from)) {
          if (!ar)
            ar = Array.prototype.slice.call(from, 0, i);
          ar[i] = from[i];
        }
      }
    return to.concat(ar || Array.prototype.slice.call(from));
  };
  var Default5 = {
    placement: "bottom",
    triggerType: "click",
    offsetSkidding: 0,
    offsetDistance: 10,
    delay: 300,
    ignoreClickOutsideClass: false,
    onShow: function() {
    },
    onHide: function() {
    },
    onToggle: function() {
    }
  };
  var DefaultInstanceOptions5 = {
    id: null,
    override: true
  };
  var Dropdown = (
    /** @class */
    function() {
      function Dropdown2(targetElement, triggerElement, options, instanceOptions) {
        if (targetElement === void 0) {
          targetElement = null;
        }
        if (triggerElement === void 0) {
          triggerElement = null;
        }
        if (options === void 0) {
          options = Default5;
        }
        if (instanceOptions === void 0) {
          instanceOptions = DefaultInstanceOptions5;
        }
        this._instanceId = instanceOptions.id ? instanceOptions.id : targetElement.id;
        this._targetEl = targetElement;
        this._triggerEl = triggerElement;
        this._options = __assign5(__assign5({}, Default5), options);
        this._popperInstance = null;
        this._visible = false;
        this._initialized = false;
        this.init();
        instances_default.addInstance("Dropdown", this, this._instanceId, instanceOptions.override);
      }
      Dropdown2.prototype.init = function() {
        if (this._triggerEl && this._targetEl && !this._initialized) {
          this._popperInstance = this._createPopperInstance();
          this._setupEventListeners();
          this._initialized = true;
        }
      };
      Dropdown2.prototype.destroy = function() {
        var _this = this;
        var triggerEvents = this._getTriggerEvents();
        if (this._options.triggerType === "click") {
          triggerEvents.showEvents.forEach(function(ev) {
            _this._triggerEl.removeEventListener(ev, _this._clickHandler);
          });
        }
        if (this._options.triggerType === "hover") {
          triggerEvents.showEvents.forEach(function(ev) {
            _this._triggerEl.removeEventListener(ev, _this._hoverShowTriggerElHandler);
            _this._targetEl.removeEventListener(ev, _this._hoverShowTargetElHandler);
          });
          triggerEvents.hideEvents.forEach(function(ev) {
            _this._triggerEl.removeEventListener(ev, _this._hoverHideHandler);
            _this._targetEl.removeEventListener(ev, _this._hoverHideHandler);
          });
        }
        this._popperInstance.destroy();
        this._initialized = false;
      };
      Dropdown2.prototype.removeInstance = function() {
        instances_default.removeInstance("Dropdown", this._instanceId);
      };
      Dropdown2.prototype.destroyAndRemoveInstance = function() {
        this.destroy();
        this.removeInstance();
      };
      Dropdown2.prototype._setupEventListeners = function() {
        var _this = this;
        var triggerEvents = this._getTriggerEvents();
        this._clickHandler = function() {
          _this.toggle();
        };
        if (this._options.triggerType === "click") {
          triggerEvents.showEvents.forEach(function(ev) {
            _this._triggerEl.addEventListener(ev, _this._clickHandler);
          });
        }
        this._hoverShowTriggerElHandler = function(ev) {
          if (ev.type === "click") {
            _this.toggle();
          } else {
            setTimeout(function() {
              _this.show();
            }, _this._options.delay);
          }
        };
        this._hoverShowTargetElHandler = function() {
          _this.show();
        };
        this._hoverHideHandler = function() {
          setTimeout(function() {
            if (!_this._targetEl.matches(":hover")) {
              _this.hide();
            }
          }, _this._options.delay);
        };
        if (this._options.triggerType === "hover") {
          triggerEvents.showEvents.forEach(function(ev) {
            _this._triggerEl.addEventListener(ev, _this._hoverShowTriggerElHandler);
            _this._targetEl.addEventListener(ev, _this._hoverShowTargetElHandler);
          });
          triggerEvents.hideEvents.forEach(function(ev) {
            _this._triggerEl.addEventListener(ev, _this._hoverHideHandler);
            _this._targetEl.addEventListener(ev, _this._hoverHideHandler);
          });
        }
      };
      Dropdown2.prototype._createPopperInstance = function() {
        return createPopper(this._triggerEl, this._targetEl, {
          placement: this._options.placement,
          modifiers: [
            {
              name: "offset",
              options: {
                offset: [
                  this._options.offsetSkidding,
                  this._options.offsetDistance
                ]
              }
            }
          ]
        });
      };
      Dropdown2.prototype._setupClickOutsideListener = function() {
        var _this = this;
        this._clickOutsideEventListener = function(ev) {
          _this._handleClickOutside(ev, _this._targetEl);
        };
        document.body.addEventListener("click", this._clickOutsideEventListener, true);
      };
      Dropdown2.prototype._removeClickOutsideListener = function() {
        document.body.removeEventListener("click", this._clickOutsideEventListener, true);
      };
      Dropdown2.prototype._handleClickOutside = function(ev, targetEl) {
        var clickedEl = ev.target;
        var ignoreClickOutsideClass = this._options.ignoreClickOutsideClass;
        var isIgnored = false;
        if (ignoreClickOutsideClass) {
          var ignoredClickOutsideEls = document.querySelectorAll(".".concat(ignoreClickOutsideClass));
          ignoredClickOutsideEls.forEach(function(el) {
            if (el.contains(clickedEl)) {
              isIgnored = true;
              return;
            }
          });
        }
        if (clickedEl !== targetEl && !targetEl.contains(clickedEl) && !this._triggerEl.contains(clickedEl) && !isIgnored && this.isVisible()) {
          this.hide();
        }
      };
      Dropdown2.prototype._getTriggerEvents = function() {
        switch (this._options.triggerType) {
          case "hover":
            return {
              showEvents: ["mouseenter", "click"],
              hideEvents: ["mouseleave"]
            };
          case "click":
            return {
              showEvents: ["click"],
              hideEvents: []
            };
          case "none":
            return {
              showEvents: [],
              hideEvents: []
            };
          default:
            return {
              showEvents: ["click"],
              hideEvents: []
            };
        }
      };
      Dropdown2.prototype.toggle = function() {
        if (this.isVisible()) {
          this.hide();
        } else {
          this.show();
        }
        this._options.onToggle(this);
      };
      Dropdown2.prototype.isVisible = function() {
        return this._visible;
      };
      Dropdown2.prototype.show = function() {
        this._targetEl.classList.remove("hidden");
        this._targetEl.classList.add("block");
        this._popperInstance.setOptions(function(options) {
          return __assign5(__assign5({}, options), { modifiers: __spreadArray(__spreadArray([], options.modifiers, true), [
            { name: "eventListeners", enabled: true }
          ], false) });
        });
        this._setupClickOutsideListener();
        this._popperInstance.update();
        this._visible = true;
        this._options.onShow(this);
      };
      Dropdown2.prototype.hide = function() {
        this._targetEl.classList.remove("block");
        this._targetEl.classList.add("hidden");
        this._popperInstance.setOptions(function(options) {
          return __assign5(__assign5({}, options), { modifiers: __spreadArray(__spreadArray([], options.modifiers, true), [
            { name: "eventListeners", enabled: false }
          ], false) });
        });
        this._visible = false;
        this._removeClickOutsideListener();
        this._options.onHide(this);
      };
      Dropdown2.prototype.updateOnShow = function(callback) {
        this._options.onShow = callback;
      };
      Dropdown2.prototype.updateOnHide = function(callback) {
        this._options.onHide = callback;
      };
      Dropdown2.prototype.updateOnToggle = function(callback) {
        this._options.onToggle = callback;
      };
      return Dropdown2;
    }()
  );
  function initDropdowns() {
    document.querySelectorAll("[data-dropdown-toggle]").forEach(function($triggerEl) {
      var dropdownId = $triggerEl.getAttribute("data-dropdown-toggle");
      var $dropdownEl = document.getElementById(dropdownId);
      if ($dropdownEl) {
        var placement = $triggerEl.getAttribute("data-dropdown-placement");
        var offsetSkidding = $triggerEl.getAttribute("data-dropdown-offset-skidding");
        var offsetDistance = $triggerEl.getAttribute("data-dropdown-offset-distance");
        var triggerType = $triggerEl.getAttribute("data-dropdown-trigger");
        var delay = $triggerEl.getAttribute("data-dropdown-delay");
        var ignoreClickOutsideClass = $triggerEl.getAttribute("data-dropdown-ignore-click-outside-class");
        new Dropdown($dropdownEl, $triggerEl, {
          placement: placement ? placement : Default5.placement,
          triggerType: triggerType ? triggerType : Default5.triggerType,
          offsetSkidding: offsetSkidding ? parseInt(offsetSkidding) : Default5.offsetSkidding,
          offsetDistance: offsetDistance ? parseInt(offsetDistance) : Default5.offsetDistance,
          delay: delay ? parseInt(delay) : Default5.delay,
          ignoreClickOutsideClass: ignoreClickOutsideClass ? ignoreClickOutsideClass : Default5.ignoreClickOutsideClass
        });
      } else {
        console.error('The dropdown element with id "'.concat(dropdownId, '" does not exist. Please check the data-dropdown-toggle attribute.'));
      }
    });
  }
  if (typeof window !== "undefined") {
    window.Dropdown = Dropdown;
    window.initDropdowns = initDropdowns;
  }
  var dropdown_default = Dropdown;

  // node_modules/flowbite/lib/esm/components/modal/index.js
  var __assign6 = function() {
    __assign6 = Object.assign || function(t) {
      for (var s, i = 1, n = arguments.length; i < n; i++) {
        s = arguments[i];
        for (var p in s)
          if (Object.prototype.hasOwnProperty.call(s, p))
            t[p] = s[p];
      }
      return t;
    };
    return __assign6.apply(this, arguments);
  };
  var Default6 = {
    placement: "center",
    backdropClasses: "bg-gray-900/50 dark:bg-gray-900/80 fixed inset-0 z-40",
    backdrop: "dynamic",
    closable: true,
    onHide: function() {
    },
    onShow: function() {
    },
    onToggle: function() {
    }
  };
  var DefaultInstanceOptions6 = {
    id: null,
    override: true
  };
  var Modal = (
    /** @class */
    function() {
      function Modal2(targetEl, options, instanceOptions) {
        if (targetEl === void 0) {
          targetEl = null;
        }
        if (options === void 0) {
          options = Default6;
        }
        if (instanceOptions === void 0) {
          instanceOptions = DefaultInstanceOptions6;
        }
        this._eventListenerInstances = [];
        this._instanceId = instanceOptions.id ? instanceOptions.id : targetEl.id;
        this._targetEl = targetEl;
        this._options = __assign6(__assign6({}, Default6), options);
        this._isHidden = true;
        this._backdropEl = null;
        this._initialized = false;
        this.init();
        instances_default.addInstance("Modal", this, this._instanceId, instanceOptions.override);
      }
      Modal2.prototype.init = function() {
        var _this = this;
        if (this._targetEl && !this._initialized) {
          this._getPlacementClasses().map(function(c) {
            _this._targetEl.classList.add(c);
          });
          this._initialized = true;
        }
      };
      Modal2.prototype.destroy = function() {
        if (this._initialized) {
          this.removeAllEventListenerInstances();
          this._destroyBackdropEl();
          this._initialized = false;
        }
      };
      Modal2.prototype.removeInstance = function() {
        instances_default.removeInstance("Modal", this._instanceId);
      };
      Modal2.prototype.destroyAndRemoveInstance = function() {
        this.destroy();
        this.removeInstance();
      };
      Modal2.prototype._createBackdrop = function() {
        var _a;
        if (this._isHidden) {
          var backdropEl = document.createElement("div");
          backdropEl.setAttribute("modal-backdrop", "");
          (_a = backdropEl.classList).add.apply(_a, this._options.backdropClasses.split(" "));
          document.querySelector("body").append(backdropEl);
          this._backdropEl = backdropEl;
        }
      };
      Modal2.prototype._destroyBackdropEl = function() {
        if (!this._isHidden) {
          document.querySelector("[modal-backdrop]").remove();
        }
      };
      Modal2.prototype._setupModalCloseEventListeners = function() {
        var _this = this;
        if (this._options.backdrop === "dynamic") {
          this._clickOutsideEventListener = function(ev) {
            _this._handleOutsideClick(ev.target);
          };
          this._targetEl.addEventListener("click", this._clickOutsideEventListener, true);
        }
        this._keydownEventListener = function(ev) {
          if (ev.key === "Escape") {
            _this.hide();
          }
        };
        document.body.addEventListener("keydown", this._keydownEventListener, true);
      };
      Modal2.prototype._removeModalCloseEventListeners = function() {
        if (this._options.backdrop === "dynamic") {
          this._targetEl.removeEventListener("click", this._clickOutsideEventListener, true);
        }
        document.body.removeEventListener("keydown", this._keydownEventListener, true);
      };
      Modal2.prototype._handleOutsideClick = function(target) {
        if (target === this._targetEl || target === this._backdropEl && this.isVisible()) {
          this.hide();
        }
      };
      Modal2.prototype._getPlacementClasses = function() {
        switch (this._options.placement) {
          case "top-left":
            return ["justify-start", "items-start"];
          case "top-center":
            return ["justify-center", "items-start"];
          case "top-right":
            return ["justify-end", "items-start"];
          case "center-left":
            return ["justify-start", "items-center"];
          case "center":
            return ["justify-center", "items-center"];
          case "center-right":
            return ["justify-end", "items-center"];
          case "bottom-left":
            return ["justify-start", "items-end"];
          case "bottom-center":
            return ["justify-center", "items-end"];
          case "bottom-right":
            return ["justify-end", "items-end"];
          default:
            return ["justify-center", "items-center"];
        }
      };
      Modal2.prototype.toggle = function() {
        if (this._isHidden) {
          this.show();
        } else {
          this.hide();
        }
        this._options.onToggle(this);
      };
      Modal2.prototype.show = function() {
        if (this.isHidden) {
          this._targetEl.classList.add("flex");
          this._targetEl.classList.remove("hidden");
          this._targetEl.setAttribute("aria-modal", "true");
          this._targetEl.setAttribute("role", "dialog");
          this._targetEl.removeAttribute("aria-hidden");
          this._createBackdrop();
          this._isHidden = false;
          if (this._options.closable) {
            this._setupModalCloseEventListeners();
          }
          document.body.classList.add("overflow-hidden");
          this._options.onShow(this);
        }
      };
      Modal2.prototype.hide = function() {
        if (this.isVisible) {
          this._targetEl.classList.add("hidden");
          this._targetEl.classList.remove("flex");
          this._targetEl.setAttribute("aria-hidden", "true");
          this._targetEl.removeAttribute("aria-modal");
          this._targetEl.removeAttribute("role");
          this._destroyBackdropEl();
          this._isHidden = true;
          document.body.classList.remove("overflow-hidden");
          if (this._options.closable) {
            this._removeModalCloseEventListeners();
          }
          this._options.onHide(this);
        }
      };
      Modal2.prototype.isVisible = function() {
        return !this._isHidden;
      };
      Modal2.prototype.isHidden = function() {
        return this._isHidden;
      };
      Modal2.prototype.addEventListenerInstance = function(element, type, handler) {
        this._eventListenerInstances.push({
          element,
          type,
          handler
        });
      };
      Modal2.prototype.removeAllEventListenerInstances = function() {
        this._eventListenerInstances.map(function(eventListenerInstance) {
          eventListenerInstance.element.removeEventListener(eventListenerInstance.type, eventListenerInstance.handler);
        });
        this._eventListenerInstances = [];
      };
      Modal2.prototype.getAllEventListenerInstances = function() {
        return this._eventListenerInstances;
      };
      Modal2.prototype.updateOnShow = function(callback) {
        this._options.onShow = callback;
      };
      Modal2.prototype.updateOnHide = function(callback) {
        this._options.onHide = callback;
      };
      Modal2.prototype.updateOnToggle = function(callback) {
        this._options.onToggle = callback;
      };
      return Modal2;
    }()
  );
  function initModals() {
    document.querySelectorAll("[data-modal-target]").forEach(function($triggerEl) {
      var modalId = $triggerEl.getAttribute("data-modal-target");
      var $modalEl = document.getElementById(modalId);
      if ($modalEl) {
        var placement = $modalEl.getAttribute("data-modal-placement");
        var backdrop = $modalEl.getAttribute("data-modal-backdrop");
        new Modal($modalEl, {
          placement: placement ? placement : Default6.placement,
          backdrop: backdrop ? backdrop : Default6.backdrop
        });
      } else {
        console.error("Modal with id ".concat(modalId, " does not exist. Are you sure that the data-modal-target attribute points to the correct modal id?."));
      }
    });
    document.querySelectorAll("[data-modal-toggle]").forEach(function($triggerEl) {
      var modalId = $triggerEl.getAttribute("data-modal-toggle");
      var $modalEl = document.getElementById(modalId);
      if ($modalEl) {
        var modal_1 = instances_default.getInstance("Modal", modalId);
        if (modal_1) {
          var toggleModal = function() {
            modal_1.toggle();
          };
          $triggerEl.addEventListener("click", toggleModal);
          modal_1.addEventListenerInstance($triggerEl, "click", toggleModal);
        } else {
          console.error("Modal with id ".concat(modalId, " has not been initialized. Please initialize it using the data-modal-target attribute."));
        }
      } else {
        console.error("Modal with id ".concat(modalId, " does not exist. Are you sure that the data-modal-toggle attribute points to the correct modal id?"));
      }
    });
    document.querySelectorAll("[data-modal-show]").forEach(function($triggerEl) {
      var modalId = $triggerEl.getAttribute("data-modal-show");
      var $modalEl = document.getElementById(modalId);
      if ($modalEl) {
        var modal_2 = instances_default.getInstance("Modal", modalId);
        if (modal_2) {
          var showModal = function() {
            modal_2.show();
          };
          $triggerEl.addEventListener("click", showModal);
          modal_2.addEventListenerInstance($triggerEl, "click", showModal);
        } else {
          console.error("Modal with id ".concat(modalId, " has not been initialized. Please initialize it using the data-modal-target attribute."));
        }
      } else {
        console.error("Modal with id ".concat(modalId, " does not exist. Are you sure that the data-modal-show attribute points to the correct modal id?"));
      }
    });
    document.querySelectorAll("[data-modal-hide]").forEach(function($triggerEl) {
      var modalId = $triggerEl.getAttribute("data-modal-hide");
      var $modalEl = document.getElementById(modalId);
      if ($modalEl) {
        var modal_3 = instances_default.getInstance("Modal", modalId);
        if (modal_3) {
          var hideModal = function() {
            modal_3.hide();
          };
          $triggerEl.addEventListener("click", hideModal);
          modal_3.addEventListenerInstance($triggerEl, "click", hideModal);
        } else {
          console.error("Modal with id ".concat(modalId, " has not been initialized. Please initialize it using the data-modal-target attribute."));
        }
      } else {
        console.error("Modal with id ".concat(modalId, " does not exist. Are you sure that the data-modal-hide attribute points to the correct modal id?"));
      }
    });
  }
  if (typeof window !== "undefined") {
    window.Modal = Modal;
    window.initModals = initModals;
  }

  // node_modules/flowbite/lib/esm/components/drawer/index.js
  var __assign7 = function() {
    __assign7 = Object.assign || function(t) {
      for (var s, i = 1, n = arguments.length; i < n; i++) {
        s = arguments[i];
        for (var p in s)
          if (Object.prototype.hasOwnProperty.call(s, p))
            t[p] = s[p];
      }
      return t;
    };
    return __assign7.apply(this, arguments);
  };
  var Default7 = {
    placement: "left",
    bodyScrolling: false,
    backdrop: true,
    edge: false,
    edgeOffset: "bottom-[60px]",
    backdropClasses: "bg-gray-900/50 dark:bg-gray-900/80 fixed inset-0 z-30",
    onShow: function() {
    },
    onHide: function() {
    },
    onToggle: function() {
    }
  };
  var DefaultInstanceOptions7 = {
    id: null,
    override: true
  };
  var Drawer = (
    /** @class */
    function() {
      function Drawer2(targetEl, options, instanceOptions) {
        if (targetEl === void 0) {
          targetEl = null;
        }
        if (options === void 0) {
          options = Default7;
        }
        if (instanceOptions === void 0) {
          instanceOptions = DefaultInstanceOptions7;
        }
        this._eventListenerInstances = [];
        this._instanceId = instanceOptions.id ? instanceOptions.id : targetEl.id;
        this._targetEl = targetEl;
        this._options = __assign7(__assign7({}, Default7), options);
        this._visible = false;
        this._initialized = false;
        this.init();
        instances_default.addInstance("Drawer", this, this._instanceId, instanceOptions.override);
      }
      Drawer2.prototype.init = function() {
        var _this = this;
        if (this._targetEl && !this._initialized) {
          this._targetEl.setAttribute("aria-hidden", "true");
          this._targetEl.classList.add("transition-transform");
          this._getPlacementClasses(this._options.placement).base.map(function(c) {
            _this._targetEl.classList.add(c);
          });
          this._handleEscapeKey = function(event) {
            if (event.key === "Escape") {
              if (_this.isVisible()) {
                _this.hide();
              }
            }
          };
          document.addEventListener("keydown", this._handleEscapeKey);
          this._initialized = true;
        }
      };
      Drawer2.prototype.destroy = function() {
        if (this._initialized) {
          this.removeAllEventListenerInstances();
          this._destroyBackdropEl();
          document.removeEventListener("keydown", this._handleEscapeKey);
          this._initialized = false;
        }
      };
      Drawer2.prototype.removeInstance = function() {
        instances_default.removeInstance("Drawer", this._instanceId);
      };
      Drawer2.prototype.destroyAndRemoveInstance = function() {
        this.destroy();
        this.removeInstance();
      };
      Drawer2.prototype.hide = function() {
        var _this = this;
        if (this._options.edge) {
          this._getPlacementClasses(this._options.placement + "-edge").active.map(function(c) {
            _this._targetEl.classList.remove(c);
          });
          this._getPlacementClasses(this._options.placement + "-edge").inactive.map(function(c) {
            _this._targetEl.classList.add(c);
          });
        } else {
          this._getPlacementClasses(this._options.placement).active.map(function(c) {
            _this._targetEl.classList.remove(c);
          });
          this._getPlacementClasses(this._options.placement).inactive.map(function(c) {
            _this._targetEl.classList.add(c);
          });
        }
        this._targetEl.setAttribute("aria-hidden", "true");
        this._targetEl.removeAttribute("aria-modal");
        this._targetEl.removeAttribute("role");
        if (!this._options.bodyScrolling) {
          document.body.classList.remove("overflow-hidden");
        }
        if (this._options.backdrop) {
          this._destroyBackdropEl();
        }
        this._visible = false;
        this._options.onHide(this);
      };
      Drawer2.prototype.show = function() {
        var _this = this;
        if (this._options.edge) {
          this._getPlacementClasses(this._options.placement + "-edge").active.map(function(c) {
            _this._targetEl.classList.add(c);
          });
          this._getPlacementClasses(this._options.placement + "-edge").inactive.map(function(c) {
            _this._targetEl.classList.remove(c);
          });
        } else {
          this._getPlacementClasses(this._options.placement).active.map(function(c) {
            _this._targetEl.classList.add(c);
          });
          this._getPlacementClasses(this._options.placement).inactive.map(function(c) {
            _this._targetEl.classList.remove(c);
          });
        }
        this._targetEl.setAttribute("aria-modal", "true");
        this._targetEl.setAttribute("role", "dialog");
        this._targetEl.removeAttribute("aria-hidden");
        if (!this._options.bodyScrolling) {
          document.body.classList.add("overflow-hidden");
        }
        if (this._options.backdrop) {
          this._createBackdrop();
        }
        this._visible = true;
        this._options.onShow(this);
      };
      Drawer2.prototype.toggle = function() {
        if (this.isVisible()) {
          this.hide();
        } else {
          this.show();
        }
      };
      Drawer2.prototype._createBackdrop = function() {
        var _a;
        var _this = this;
        if (!this._visible) {
          var backdropEl = document.createElement("div");
          backdropEl.setAttribute("drawer-backdrop", "");
          (_a = backdropEl.classList).add.apply(_a, this._options.backdropClasses.split(" "));
          document.querySelector("body").append(backdropEl);
          backdropEl.addEventListener("click", function() {
            _this.hide();
          });
        }
      };
      Drawer2.prototype._destroyBackdropEl = function() {
        if (this._visible && document.querySelector("[drawer-backdrop]") !== null) {
          document.querySelector("[drawer-backdrop]").remove();
        }
      };
      Drawer2.prototype._getPlacementClasses = function(placement) {
        switch (placement) {
          case "top":
            return {
              base: ["top-0", "left-0", "right-0"],
              active: ["transform-none"],
              inactive: ["-translate-y-full"]
            };
          case "right":
            return {
              base: ["right-0", "top-0"],
              active: ["transform-none"],
              inactive: ["translate-x-full"]
            };
          case "bottom":
            return {
              base: ["bottom-0", "left-0", "right-0"],
              active: ["transform-none"],
              inactive: ["translate-y-full"]
            };
          case "left":
            return {
              base: ["left-0", "top-0"],
              active: ["transform-none"],
              inactive: ["-translate-x-full"]
            };
          case "bottom-edge":
            return {
              base: ["left-0", "top-0"],
              active: ["transform-none"],
              inactive: ["translate-y-full", this._options.edgeOffset]
            };
          default:
            return {
              base: ["left-0", "top-0"],
              active: ["transform-none"],
              inactive: ["-translate-x-full"]
            };
        }
      };
      Drawer2.prototype.isHidden = function() {
        return !this._visible;
      };
      Drawer2.prototype.isVisible = function() {
        return this._visible;
      };
      Drawer2.prototype.addEventListenerInstance = function(element, type, handler) {
        this._eventListenerInstances.push({
          element,
          type,
          handler
        });
      };
      Drawer2.prototype.removeAllEventListenerInstances = function() {
        this._eventListenerInstances.map(function(eventListenerInstance) {
          eventListenerInstance.element.removeEventListener(eventListenerInstance.type, eventListenerInstance.handler);
        });
        this._eventListenerInstances = [];
      };
      Drawer2.prototype.getAllEventListenerInstances = function() {
        return this._eventListenerInstances;
      };
      Drawer2.prototype.updateOnShow = function(callback) {
        this._options.onShow = callback;
      };
      Drawer2.prototype.updateOnHide = function(callback) {
        this._options.onHide = callback;
      };
      Drawer2.prototype.updateOnToggle = function(callback) {
        this._options.onToggle = callback;
      };
      return Drawer2;
    }()
  );
  function initDrawers() {
    document.querySelectorAll("[data-drawer-target]").forEach(function($triggerEl) {
      var drawerId = $triggerEl.getAttribute("data-drawer-target");
      var $drawerEl = document.getElementById(drawerId);
      if ($drawerEl) {
        var placement = $triggerEl.getAttribute("data-drawer-placement");
        var bodyScrolling = $triggerEl.getAttribute("data-drawer-body-scrolling");
        var backdrop = $triggerEl.getAttribute("data-drawer-backdrop");
        var edge = $triggerEl.getAttribute("data-drawer-edge");
        var edgeOffset = $triggerEl.getAttribute("data-drawer-edge-offset");
        new Drawer($drawerEl, {
          placement: placement ? placement : Default7.placement,
          bodyScrolling: bodyScrolling ? bodyScrolling === "true" ? true : false : Default7.bodyScrolling,
          backdrop: backdrop ? backdrop === "true" ? true : false : Default7.backdrop,
          edge: edge ? edge === "true" ? true : false : Default7.edge,
          edgeOffset: edgeOffset ? edgeOffset : Default7.edgeOffset
        });
      } else {
        console.error("Drawer with id ".concat(drawerId, " not found. Are you sure that the data-drawer-target attribute points to the correct drawer id?"));
      }
    });
    document.querySelectorAll("[data-drawer-toggle]").forEach(function($triggerEl) {
      var drawerId = $triggerEl.getAttribute("data-drawer-toggle");
      var $drawerEl = document.getElementById(drawerId);
      if ($drawerEl) {
        var drawer_1 = instances_default.getInstance("Drawer", drawerId);
        if (drawer_1) {
          var toggleDrawer = function() {
            drawer_1.toggle();
          };
          $triggerEl.addEventListener("click", toggleDrawer);
          drawer_1.addEventListenerInstance($triggerEl, "click", toggleDrawer);
        } else {
          console.error("Drawer with id ".concat(drawerId, " has not been initialized. Please initialize it using the data-drawer-target attribute."));
        }
      } else {
        console.error("Drawer with id ".concat(drawerId, " not found. Are you sure that the data-drawer-target attribute points to the correct drawer id?"));
      }
    });
    document.querySelectorAll("[data-drawer-dismiss], [data-drawer-hide]").forEach(function($triggerEl) {
      var drawerId = $triggerEl.getAttribute("data-drawer-dismiss") ? $triggerEl.getAttribute("data-drawer-dismiss") : $triggerEl.getAttribute("data-drawer-hide");
      var $drawerEl = document.getElementById(drawerId);
      if ($drawerEl) {
        var drawer_2 = instances_default.getInstance("Drawer", drawerId);
        if (drawer_2) {
          var hideDrawer = function() {
            drawer_2.hide();
          };
          $triggerEl.addEventListener("click", hideDrawer);
          drawer_2.addEventListenerInstance($triggerEl, "click", hideDrawer);
        } else {
          console.error("Drawer with id ".concat(drawerId, " has not been initialized. Please initialize it using the data-drawer-target attribute."));
        }
      } else {
        console.error("Drawer with id ".concat(drawerId, " not found. Are you sure that the data-drawer-target attribute points to the correct drawer id"));
      }
    });
    document.querySelectorAll("[data-drawer-show]").forEach(function($triggerEl) {
      var drawerId = $triggerEl.getAttribute("data-drawer-show");
      var $drawerEl = document.getElementById(drawerId);
      if ($drawerEl) {
        var drawer_3 = instances_default.getInstance("Drawer", drawerId);
        if (drawer_3) {
          var showDrawer = function() {
            drawer_3.show();
          };
          $triggerEl.addEventListener("click", showDrawer);
          drawer_3.addEventListenerInstance($triggerEl, "click", showDrawer);
        } else {
          console.error("Drawer with id ".concat(drawerId, " has not been initialized. Please initialize it using the data-drawer-target attribute."));
        }
      } else {
        console.error("Drawer with id ".concat(drawerId, " not found. Are you sure that the data-drawer-target attribute points to the correct drawer id?"));
      }
    });
  }
  if (typeof window !== "undefined") {
    window.Drawer = Drawer;
    window.initDrawers = initDrawers;
  }

  // node_modules/flowbite/lib/esm/components/tabs/index.js
  var __assign8 = function() {
    __assign8 = Object.assign || function(t) {
      for (var s, i = 1, n = arguments.length; i < n; i++) {
        s = arguments[i];
        for (var p in s)
          if (Object.prototype.hasOwnProperty.call(s, p))
            t[p] = s[p];
      }
      return t;
    };
    return __assign8.apply(this, arguments);
  };
  var Default8 = {
    defaultTabId: null,
    activeClasses: "text-blue-600 hover:text-blue-600 dark:text-blue-500 dark:hover:text-blue-500 border-blue-600 dark:border-blue-500",
    inactiveClasses: "dark:border-transparent text-gray-500 hover:text-gray-600 dark:text-gray-400 border-gray-100 hover:border-gray-300 dark:border-gray-700 dark:hover:text-gray-300",
    onShow: function() {
    }
  };
  var DefaultInstanceOptions8 = {
    id: null,
    override: true
  };
  var Tabs = (
    /** @class */
    function() {
      function Tabs2(tabsEl, items, options, instanceOptions) {
        if (tabsEl === void 0) {
          tabsEl = null;
        }
        if (items === void 0) {
          items = [];
        }
        if (options === void 0) {
          options = Default8;
        }
        if (instanceOptions === void 0) {
          instanceOptions = DefaultInstanceOptions8;
        }
        this._instanceId = instanceOptions.id ? instanceOptions.id : tabsEl.id;
        this._tabsEl = tabsEl;
        this._items = items;
        this._activeTab = options ? this.getTab(options.defaultTabId) : null;
        this._options = __assign8(__assign8({}, Default8), options);
        this._initialized = false;
        this.init();
        instances_default.addInstance("Tabs", this, this._tabsEl.id, true);
        instances_default.addInstance("Tabs", this, this._instanceId, instanceOptions.override);
      }
      Tabs2.prototype.init = function() {
        var _this = this;
        if (this._items.length && !this._initialized) {
          if (!this._activeTab) {
            this.setActiveTab(this._items[0]);
          }
          this.show(this._activeTab.id, true);
          this._items.map(function(tab) {
            tab.triggerEl.addEventListener("click", function(event) {
              event.preventDefault();
              _this.show(tab.id);
            });
          });
        }
      };
      Tabs2.prototype.destroy = function() {
        if (this._initialized) {
          this._initialized = false;
        }
      };
      Tabs2.prototype.removeInstance = function() {
        this.destroy();
        instances_default.removeInstance("Tabs", this._instanceId);
      };
      Tabs2.prototype.destroyAndRemoveInstance = function() {
        this.destroy();
        this.removeInstance();
      };
      Tabs2.prototype.getActiveTab = function() {
        return this._activeTab;
      };
      Tabs2.prototype.setActiveTab = function(tab) {
        this._activeTab = tab;
      };
      Tabs2.prototype.getTab = function(id) {
        return this._items.filter(function(t) {
          return t.id === id;
        })[0];
      };
      Tabs2.prototype.show = function(id, forceShow) {
        var _a, _b;
        var _this = this;
        if (forceShow === void 0) {
          forceShow = false;
        }
        var tab = this.getTab(id);
        if (tab === this._activeTab && !forceShow) {
          return;
        }
        this._items.map(function(t) {
          var _a2, _b2;
          if (t !== tab) {
            (_a2 = t.triggerEl.classList).remove.apply(_a2, _this._options.activeClasses.split(" "));
            (_b2 = t.triggerEl.classList).add.apply(_b2, _this._options.inactiveClasses.split(" "));
            t.targetEl.classList.add("hidden");
            t.triggerEl.setAttribute("aria-selected", "false");
          }
        });
        (_a = tab.triggerEl.classList).add.apply(_a, this._options.activeClasses.split(" "));
        (_b = tab.triggerEl.classList).remove.apply(_b, this._options.inactiveClasses.split(" "));
        tab.triggerEl.setAttribute("aria-selected", "true");
        tab.targetEl.classList.remove("hidden");
        this.setActiveTab(tab);
        this._options.onShow(this, tab);
      };
      Tabs2.prototype.updateOnShow = function(callback) {
        this._options.onShow = callback;
      };
      return Tabs2;
    }()
  );
  function initTabs() {
    document.querySelectorAll("[data-tabs-toggle]").forEach(function($parentEl) {
      var tabItems = [];
      var activeClasses = $parentEl.getAttribute("data-tabs-active-classes");
      var inactiveClasses = $parentEl.getAttribute("data-tabs-inactive-classes");
      var defaultTabId = null;
      $parentEl.querySelectorAll('[role="tab"]').forEach(function($triggerEl) {
        var isActive = $triggerEl.getAttribute("aria-selected") === "true";
        var tab = {
          id: $triggerEl.getAttribute("data-tabs-target"),
          triggerEl: $triggerEl,
          targetEl: document.querySelector($triggerEl.getAttribute("data-tabs-target"))
        };
        tabItems.push(tab);
        if (isActive) {
          defaultTabId = tab.id;
        }
      });
      new Tabs($parentEl, tabItems, {
        defaultTabId,
        activeClasses: activeClasses ? activeClasses : Default8.activeClasses,
        inactiveClasses: inactiveClasses ? inactiveClasses : Default8.inactiveClasses
      });
    });
  }
  if (typeof window !== "undefined") {
    window.Tabs = Tabs;
    window.initTabs = initTabs;
  }

  // node_modules/flowbite/lib/esm/components/tooltip/index.js
  var __assign9 = function() {
    __assign9 = Object.assign || function(t) {
      for (var s, i = 1, n = arguments.length; i < n; i++) {
        s = arguments[i];
        for (var p in s)
          if (Object.prototype.hasOwnProperty.call(s, p))
            t[p] = s[p];
      }
      return t;
    };
    return __assign9.apply(this, arguments);
  };
  var __spreadArray2 = function(to, from, pack) {
    if (pack || arguments.length === 2)
      for (var i = 0, l = from.length, ar; i < l; i++) {
        if (ar || !(i in from)) {
          if (!ar)
            ar = Array.prototype.slice.call(from, 0, i);
          ar[i] = from[i];
        }
      }
    return to.concat(ar || Array.prototype.slice.call(from));
  };
  var Default9 = {
    placement: "top",
    triggerType: "hover",
    onShow: function() {
    },
    onHide: function() {
    },
    onToggle: function() {
    }
  };
  var DefaultInstanceOptions9 = {
    id: null,
    override: true
  };
  var Tooltip = (
    /** @class */
    function() {
      function Tooltip2(targetEl, triggerEl, options, instanceOptions) {
        if (targetEl === void 0) {
          targetEl = null;
        }
        if (triggerEl === void 0) {
          triggerEl = null;
        }
        if (options === void 0) {
          options = Default9;
        }
        if (instanceOptions === void 0) {
          instanceOptions = DefaultInstanceOptions9;
        }
        this._instanceId = instanceOptions.id ? instanceOptions.id : targetEl.id;
        this._targetEl = targetEl;
        this._triggerEl = triggerEl;
        this._options = __assign9(__assign9({}, Default9), options);
        this._popperInstance = null;
        this._visible = false;
        this._initialized = false;
        this.init();
        instances_default.addInstance("Tooltip", this, this._instanceId, instanceOptions.override);
      }
      Tooltip2.prototype.init = function() {
        if (this._triggerEl && this._targetEl && !this._initialized) {
          this._setupEventListeners();
          this._popperInstance = this._createPopperInstance();
          this._initialized = true;
        }
      };
      Tooltip2.prototype.destroy = function() {
        var _this = this;
        if (this._initialized) {
          var triggerEvents = this._getTriggerEvents();
          triggerEvents.showEvents.forEach(function(ev) {
            _this._triggerEl.removeEventListener(ev, _this._showHandler);
          });
          triggerEvents.hideEvents.forEach(function(ev) {
            _this._triggerEl.removeEventListener(ev, _this._hideHandler);
          });
          this._removeKeydownListener();
          this._removeClickOutsideListener();
          if (this._popperInstance) {
            this._popperInstance.destroy();
          }
          this._initialized = false;
        }
      };
      Tooltip2.prototype.removeInstance = function() {
        instances_default.removeInstance("Tooltip", this._instanceId);
      };
      Tooltip2.prototype.destroyAndRemoveInstance = function() {
        this.destroy();
        this.removeInstance();
      };
      Tooltip2.prototype._setupEventListeners = function() {
        var _this = this;
        var triggerEvents = this._getTriggerEvents();
        this._showHandler = function() {
          _this.show();
        };
        this._hideHandler = function() {
          _this.hide();
        };
        triggerEvents.showEvents.forEach(function(ev) {
          _this._triggerEl.addEventListener(ev, _this._showHandler);
        });
        triggerEvents.hideEvents.forEach(function(ev) {
          _this._triggerEl.addEventListener(ev, _this._hideHandler);
        });
      };
      Tooltip2.prototype._createPopperInstance = function() {
        return createPopper(this._triggerEl, this._targetEl, {
          placement: this._options.placement,
          modifiers: [
            {
              name: "offset",
              options: {
                offset: [0, 8]
              }
            }
          ]
        });
      };
      Tooltip2.prototype._getTriggerEvents = function() {
        switch (this._options.triggerType) {
          case "hover":
            return {
              showEvents: ["mouseenter", "focus"],
              hideEvents: ["mouseleave", "blur"]
            };
          case "click":
            return {
              showEvents: ["click", "focus"],
              hideEvents: ["focusout", "blur"]
            };
          case "none":
            return {
              showEvents: [],
              hideEvents: []
            };
          default:
            return {
              showEvents: ["mouseenter", "focus"],
              hideEvents: ["mouseleave", "blur"]
            };
        }
      };
      Tooltip2.prototype._setupKeydownListener = function() {
        var _this = this;
        this._keydownEventListener = function(ev) {
          if (ev.key === "Escape") {
            _this.hide();
          }
        };
        document.body.addEventListener("keydown", this._keydownEventListener, true);
      };
      Tooltip2.prototype._removeKeydownListener = function() {
        document.body.removeEventListener("keydown", this._keydownEventListener, true);
      };
      Tooltip2.prototype._setupClickOutsideListener = function() {
        var _this = this;
        this._clickOutsideEventListener = function(ev) {
          _this._handleClickOutside(ev, _this._targetEl);
        };
        document.body.addEventListener("click", this._clickOutsideEventListener, true);
      };
      Tooltip2.prototype._removeClickOutsideListener = function() {
        document.body.removeEventListener("click", this._clickOutsideEventListener, true);
      };
      Tooltip2.prototype._handleClickOutside = function(ev, targetEl) {
        var clickedEl = ev.target;
        if (clickedEl !== targetEl && !targetEl.contains(clickedEl) && !this._triggerEl.contains(clickedEl) && this.isVisible()) {
          this.hide();
        }
      };
      Tooltip2.prototype.isVisible = function() {
        return this._visible;
      };
      Tooltip2.prototype.toggle = function() {
        if (this.isVisible()) {
          this.hide();
        } else {
          this.show();
        }
      };
      Tooltip2.prototype.show = function() {
        this._targetEl.classList.remove("opacity-0", "invisible");
        this._targetEl.classList.add("opacity-100", "visible");
        this._popperInstance.setOptions(function(options) {
          return __assign9(__assign9({}, options), { modifiers: __spreadArray2(__spreadArray2([], options.modifiers, true), [
            { name: "eventListeners", enabled: true }
          ], false) });
        });
        this._setupClickOutsideListener();
        this._setupKeydownListener();
        this._popperInstance.update();
        this._visible = true;
        this._options.onShow(this);
      };
      Tooltip2.prototype.hide = function() {
        this._targetEl.classList.remove("opacity-100", "visible");
        this._targetEl.classList.add("opacity-0", "invisible");
        this._popperInstance.setOptions(function(options) {
          return __assign9(__assign9({}, options), { modifiers: __spreadArray2(__spreadArray2([], options.modifiers, true), [
            { name: "eventListeners", enabled: false }
          ], false) });
        });
        this._removeClickOutsideListener();
        this._removeKeydownListener();
        this._visible = false;
        this._options.onHide(this);
      };
      Tooltip2.prototype.updateOnShow = function(callback) {
        this._options.onShow = callback;
      };
      Tooltip2.prototype.updateOnHide = function(callback) {
        this._options.onHide = callback;
      };
      Tooltip2.prototype.updateOnToggle = function(callback) {
        this._options.onToggle = callback;
      };
      return Tooltip2;
    }()
  );
  function initTooltips() {
    document.querySelectorAll("[data-tooltip-target]").forEach(function($triggerEl) {
      var tooltipId = $triggerEl.getAttribute("data-tooltip-target");
      var $tooltipEl = document.getElementById(tooltipId);
      if ($tooltipEl) {
        var triggerType = $triggerEl.getAttribute("data-tooltip-trigger");
        var placement = $triggerEl.getAttribute("data-tooltip-placement");
        new Tooltip($tooltipEl, $triggerEl, {
          placement: placement ? placement : Default9.placement,
          triggerType: triggerType ? triggerType : Default9.triggerType
        });
      } else {
        console.error('The tooltip element with id "'.concat(tooltipId, '" does not exist. Please check the data-tooltip-target attribute.'));
      }
    });
  }
  if (typeof window !== "undefined") {
    window.Tooltip = Tooltip;
    window.initTooltips = initTooltips;
  }

  // node_modules/flowbite/lib/esm/components/popover/index.js
  var __assign10 = function() {
    __assign10 = Object.assign || function(t) {
      for (var s, i = 1, n = arguments.length; i < n; i++) {
        s = arguments[i];
        for (var p in s)
          if (Object.prototype.hasOwnProperty.call(s, p))
            t[p] = s[p];
      }
      return t;
    };
    return __assign10.apply(this, arguments);
  };
  var __spreadArray3 = function(to, from, pack) {
    if (pack || arguments.length === 2)
      for (var i = 0, l = from.length, ar; i < l; i++) {
        if (ar || !(i in from)) {
          if (!ar)
            ar = Array.prototype.slice.call(from, 0, i);
          ar[i] = from[i];
        }
      }
    return to.concat(ar || Array.prototype.slice.call(from));
  };
  var Default10 = {
    placement: "top",
    offset: 10,
    triggerType: "hover",
    onShow: function() {
    },
    onHide: function() {
    },
    onToggle: function() {
    }
  };
  var DefaultInstanceOptions10 = {
    id: null,
    override: true
  };
  var Popover = (
    /** @class */
    function() {
      function Popover2(targetEl, triggerEl, options, instanceOptions) {
        if (targetEl === void 0) {
          targetEl = null;
        }
        if (triggerEl === void 0) {
          triggerEl = null;
        }
        if (options === void 0) {
          options = Default10;
        }
        if (instanceOptions === void 0) {
          instanceOptions = DefaultInstanceOptions10;
        }
        this._instanceId = instanceOptions.id ? instanceOptions.id : targetEl.id;
        this._targetEl = targetEl;
        this._triggerEl = triggerEl;
        this._options = __assign10(__assign10({}, Default10), options);
        this._popperInstance = null;
        this._visible = false;
        this._initialized = false;
        this.init();
        instances_default.addInstance("Popover", this, instanceOptions.id ? instanceOptions.id : this._targetEl.id, instanceOptions.override);
      }
      Popover2.prototype.init = function() {
        if (this._triggerEl && this._targetEl && !this._initialized) {
          this._setupEventListeners();
          this._popperInstance = this._createPopperInstance();
          this._initialized = true;
        }
      };
      Popover2.prototype.destroy = function() {
        var _this = this;
        if (this._initialized) {
          var triggerEvents = this._getTriggerEvents();
          triggerEvents.showEvents.forEach(function(ev) {
            _this._triggerEl.removeEventListener(ev, _this._showHandler);
            _this._targetEl.removeEventListener(ev, _this._showHandler);
          });
          triggerEvents.hideEvents.forEach(function(ev) {
            _this._triggerEl.removeEventListener(ev, _this._hideHandler);
            _this._targetEl.removeEventListener(ev, _this._hideHandler);
          });
          this._removeKeydownListener();
          this._removeClickOutsideListener();
          if (this._popperInstance) {
            this._popperInstance.destroy();
          }
          this._initialized = false;
        }
      };
      Popover2.prototype.removeInstance = function() {
        instances_default.removeInstance("Popover", this._instanceId);
      };
      Popover2.prototype.destroyAndRemoveInstance = function() {
        this.destroy();
        this.removeInstance();
      };
      Popover2.prototype._setupEventListeners = function() {
        var _this = this;
        var triggerEvents = this._getTriggerEvents();
        this._showHandler = function() {
          _this.show();
        };
        this._hideHandler = function() {
          setTimeout(function() {
            if (!_this._targetEl.matches(":hover")) {
              _this.hide();
            }
          }, 100);
        };
        triggerEvents.showEvents.forEach(function(ev) {
          _this._triggerEl.addEventListener(ev, _this._showHandler);
          _this._targetEl.addEventListener(ev, _this._showHandler);
        });
        triggerEvents.hideEvents.forEach(function(ev) {
          _this._triggerEl.addEventListener(ev, _this._hideHandler);
          _this._targetEl.addEventListener(ev, _this._hideHandler);
        });
      };
      Popover2.prototype._createPopperInstance = function() {
        return createPopper(this._triggerEl, this._targetEl, {
          placement: this._options.placement,
          modifiers: [
            {
              name: "offset",
              options: {
                offset: [0, this._options.offset]
              }
            }
          ]
        });
      };
      Popover2.prototype._getTriggerEvents = function() {
        switch (this._options.triggerType) {
          case "hover":
            return {
              showEvents: ["mouseenter", "focus"],
              hideEvents: ["mouseleave", "blur"]
            };
          case "click":
            return {
              showEvents: ["click", "focus"],
              hideEvents: ["focusout", "blur"]
            };
          case "none":
            return {
              showEvents: [],
              hideEvents: []
            };
          default:
            return {
              showEvents: ["mouseenter", "focus"],
              hideEvents: ["mouseleave", "blur"]
            };
        }
      };
      Popover2.prototype._setupKeydownListener = function() {
        var _this = this;
        this._keydownEventListener = function(ev) {
          if (ev.key === "Escape") {
            _this.hide();
          }
        };
        document.body.addEventListener("keydown", this._keydownEventListener, true);
      };
      Popover2.prototype._removeKeydownListener = function() {
        document.body.removeEventListener("keydown", this._keydownEventListener, true);
      };
      Popover2.prototype._setupClickOutsideListener = function() {
        var _this = this;
        this._clickOutsideEventListener = function(ev) {
          _this._handleClickOutside(ev, _this._targetEl);
        };
        document.body.addEventListener("click", this._clickOutsideEventListener, true);
      };
      Popover2.prototype._removeClickOutsideListener = function() {
        document.body.removeEventListener("click", this._clickOutsideEventListener, true);
      };
      Popover2.prototype._handleClickOutside = function(ev, targetEl) {
        var clickedEl = ev.target;
        if (clickedEl !== targetEl && !targetEl.contains(clickedEl) && !this._triggerEl.contains(clickedEl) && this.isVisible()) {
          this.hide();
        }
      };
      Popover2.prototype.isVisible = function() {
        return this._visible;
      };
      Popover2.prototype.toggle = function() {
        if (this.isVisible()) {
          this.hide();
        } else {
          this.show();
        }
        this._options.onToggle(this);
      };
      Popover2.prototype.show = function() {
        this._targetEl.classList.remove("opacity-0", "invisible");
        this._targetEl.classList.add("opacity-100", "visible");
        this._popperInstance.setOptions(function(options) {
          return __assign10(__assign10({}, options), { modifiers: __spreadArray3(__spreadArray3([], options.modifiers, true), [
            { name: "eventListeners", enabled: true }
          ], false) });
        });
        this._setupClickOutsideListener();
        this._setupKeydownListener();
        this._popperInstance.update();
        this._visible = true;
        this._options.onShow(this);
      };
      Popover2.prototype.hide = function() {
        this._targetEl.classList.remove("opacity-100", "visible");
        this._targetEl.classList.add("opacity-0", "invisible");
        this._popperInstance.setOptions(function(options) {
          return __assign10(__assign10({}, options), { modifiers: __spreadArray3(__spreadArray3([], options.modifiers, true), [
            { name: "eventListeners", enabled: false }
          ], false) });
        });
        this._removeClickOutsideListener();
        this._removeKeydownListener();
        this._visible = false;
        this._options.onHide(this);
      };
      Popover2.prototype.updateOnShow = function(callback) {
        this._options.onShow = callback;
      };
      Popover2.prototype.updateOnHide = function(callback) {
        this._options.onHide = callback;
      };
      Popover2.prototype.updateOnToggle = function(callback) {
        this._options.onToggle = callback;
      };
      return Popover2;
    }()
  );
  function initPopovers() {
    document.querySelectorAll("[data-popover-target]").forEach(function($triggerEl) {
      var popoverID = $triggerEl.getAttribute("data-popover-target");
      var $popoverEl = document.getElementById(popoverID);
      if ($popoverEl) {
        var triggerType = $triggerEl.getAttribute("data-popover-trigger");
        var placement = $triggerEl.getAttribute("data-popover-placement");
        var offset2 = $triggerEl.getAttribute("data-popover-offset");
        new Popover($popoverEl, $triggerEl, {
          placement: placement ? placement : Default10.placement,
          offset: offset2 ? parseInt(offset2) : Default10.offset,
          triggerType: triggerType ? triggerType : Default10.triggerType
        });
      } else {
        console.error('The popover element with id "'.concat(popoverID, '" does not exist. Please check the data-popover-target attribute.'));
      }
    });
  }
  if (typeof window !== "undefined") {
    window.Popover = Popover;
    window.initPopovers = initPopovers;
  }

  // node_modules/flowbite/lib/esm/components/dial/index.js
  var __assign11 = function() {
    __assign11 = Object.assign || function(t) {
      for (var s, i = 1, n = arguments.length; i < n; i++) {
        s = arguments[i];
        for (var p in s)
          if (Object.prototype.hasOwnProperty.call(s, p))
            t[p] = s[p];
      }
      return t;
    };
    return __assign11.apply(this, arguments);
  };
  var Default11 = {
    triggerType: "hover",
    onShow: function() {
    },
    onHide: function() {
    },
    onToggle: function() {
    }
  };
  var DefaultInstanceOptions11 = {
    id: null,
    override: true
  };
  var Dial = (
    /** @class */
    function() {
      function Dial2(parentEl, triggerEl, targetEl, options, instanceOptions) {
        if (parentEl === void 0) {
          parentEl = null;
        }
        if (triggerEl === void 0) {
          triggerEl = null;
        }
        if (targetEl === void 0) {
          targetEl = null;
        }
        if (options === void 0) {
          options = Default11;
        }
        if (instanceOptions === void 0) {
          instanceOptions = DefaultInstanceOptions11;
        }
        this._instanceId = instanceOptions.id ? instanceOptions.id : targetEl.id;
        this._parentEl = parentEl;
        this._triggerEl = triggerEl;
        this._targetEl = targetEl;
        this._options = __assign11(__assign11({}, Default11), options);
        this._visible = false;
        this._initialized = false;
        this.init();
        instances_default.addInstance("Dial", this, this._instanceId, instanceOptions.override);
      }
      Dial2.prototype.init = function() {
        var _this = this;
        if (this._triggerEl && this._targetEl && !this._initialized) {
          var triggerEventTypes = this._getTriggerEventTypes(this._options.triggerType);
          this._showEventHandler = function() {
            _this.show();
          };
          triggerEventTypes.showEvents.forEach(function(ev) {
            _this._triggerEl.addEventListener(ev, _this._showEventHandler);
            _this._targetEl.addEventListener(ev, _this._showEventHandler);
          });
          this._hideEventHandler = function() {
            if (!_this._parentEl.matches(":hover")) {
              _this.hide();
            }
          };
          triggerEventTypes.hideEvents.forEach(function(ev) {
            _this._parentEl.addEventListener(ev, _this._hideEventHandler);
          });
          this._initialized = true;
        }
      };
      Dial2.prototype.destroy = function() {
        var _this = this;
        if (this._initialized) {
          var triggerEventTypes = this._getTriggerEventTypes(this._options.triggerType);
          triggerEventTypes.showEvents.forEach(function(ev) {
            _this._triggerEl.removeEventListener(ev, _this._showEventHandler);
            _this._targetEl.removeEventListener(ev, _this._showEventHandler);
          });
          triggerEventTypes.hideEvents.forEach(function(ev) {
            _this._parentEl.removeEventListener(ev, _this._hideEventHandler);
          });
          this._initialized = false;
        }
      };
      Dial2.prototype.removeInstance = function() {
        instances_default.removeInstance("Dial", this._instanceId);
      };
      Dial2.prototype.destroyAndRemoveInstance = function() {
        this.destroy();
        this.removeInstance();
      };
      Dial2.prototype.hide = function() {
        this._targetEl.classList.add("hidden");
        if (this._triggerEl) {
          this._triggerEl.setAttribute("aria-expanded", "false");
        }
        this._visible = false;
        this._options.onHide(this);
      };
      Dial2.prototype.show = function() {
        this._targetEl.classList.remove("hidden");
        if (this._triggerEl) {
          this._triggerEl.setAttribute("aria-expanded", "true");
        }
        this._visible = true;
        this._options.onShow(this);
      };
      Dial2.prototype.toggle = function() {
        if (this._visible) {
          this.hide();
        } else {
          this.show();
        }
      };
      Dial2.prototype.isHidden = function() {
        return !this._visible;
      };
      Dial2.prototype.isVisible = function() {
        return this._visible;
      };
      Dial2.prototype._getTriggerEventTypes = function(triggerType) {
        switch (triggerType) {
          case "hover":
            return {
              showEvents: ["mouseenter", "focus"],
              hideEvents: ["mouseleave", "blur"]
            };
          case "click":
            return {
              showEvents: ["click", "focus"],
              hideEvents: ["focusout", "blur"]
            };
          case "none":
            return {
              showEvents: [],
              hideEvents: []
            };
          default:
            return {
              showEvents: ["mouseenter", "focus"],
              hideEvents: ["mouseleave", "blur"]
            };
        }
      };
      Dial2.prototype.updateOnShow = function(callback) {
        this._options.onShow = callback;
      };
      Dial2.prototype.updateOnHide = function(callback) {
        this._options.onHide = callback;
      };
      Dial2.prototype.updateOnToggle = function(callback) {
        this._options.onToggle = callback;
      };
      return Dial2;
    }()
  );
  function initDials() {
    document.querySelectorAll("[data-dial-init]").forEach(function($parentEl) {
      var $triggerEl = $parentEl.querySelector("[data-dial-toggle]");
      if ($triggerEl) {
        var dialId = $triggerEl.getAttribute("data-dial-toggle");
        var $dialEl = document.getElementById(dialId);
        if ($dialEl) {
          var triggerType = $triggerEl.getAttribute("data-dial-trigger");
          new Dial($parentEl, $triggerEl, $dialEl, {
            triggerType: triggerType ? triggerType : Default11.triggerType
          });
        } else {
          console.error("Dial with id ".concat(dialId, " does not exist. Are you sure that the data-dial-toggle attribute points to the correct modal id?"));
        }
      } else {
        console.error("Dial with id ".concat($parentEl.id, " does not have a trigger element. Are you sure that the data-dial-toggle attribute exists?"));
      }
    });
  }
  if (typeof window !== "undefined") {
    window.Dial = Dial;
    window.initDials = initDials;
  }

  // node_modules/flowbite/lib/esm/components/input-counter/index.js
  var __assign12 = function() {
    __assign12 = Object.assign || function(t) {
      for (var s, i = 1, n = arguments.length; i < n; i++) {
        s = arguments[i];
        for (var p in s)
          if (Object.prototype.hasOwnProperty.call(s, p))
            t[p] = s[p];
      }
      return t;
    };
    return __assign12.apply(this, arguments);
  };
  var Default12 = {
    minValue: null,
    maxValue: null,
    onIncrement: function() {
    },
    onDecrement: function() {
    }
  };
  var DefaultInstanceOptions12 = {
    id: null,
    override: true
  };
  var InputCounter = (
    /** @class */
    function() {
      function InputCounter2(targetEl, incrementEl, decrementEl, options, instanceOptions) {
        if (targetEl === void 0) {
          targetEl = null;
        }
        if (incrementEl === void 0) {
          incrementEl = null;
        }
        if (decrementEl === void 0) {
          decrementEl = null;
        }
        if (options === void 0) {
          options = Default12;
        }
        if (instanceOptions === void 0) {
          instanceOptions = DefaultInstanceOptions12;
        }
        this._instanceId = instanceOptions.id ? instanceOptions.id : targetEl.id;
        this._targetEl = targetEl;
        this._incrementEl = incrementEl;
        this._decrementEl = decrementEl;
        this._options = __assign12(__assign12({}, Default12), options);
        this._initialized = false;
        this.init();
        instances_default.addInstance("InputCounter", this, this._instanceId, instanceOptions.override);
      }
      InputCounter2.prototype.init = function() {
        var _this = this;
        if (this._targetEl && !this._initialized) {
          this._inputHandler = function(event) {
            {
              var target = event.target;
              if (!/^\d*$/.test(target.value)) {
                target.value = target.value.replace(/[^\d]/g, "");
              }
              if (_this._options.maxValue !== null && parseInt(target.value) > _this._options.maxValue) {
                target.value = _this._options.maxValue.toString();
              }
              if (_this._options.minValue !== null && parseInt(target.value) < _this._options.minValue) {
                target.value = _this._options.minValue.toString();
              }
            }
          };
          this._incrementClickHandler = function() {
            _this.increment();
          };
          this._decrementClickHandler = function() {
            _this.decrement();
          };
          this._targetEl.addEventListener("input", this._inputHandler);
          if (this._incrementEl) {
            this._incrementEl.addEventListener("click", this._incrementClickHandler);
          }
          if (this._decrementEl) {
            this._decrementEl.addEventListener("click", this._decrementClickHandler);
          }
          this._initialized = true;
        }
      };
      InputCounter2.prototype.destroy = function() {
        if (this._targetEl && this._initialized) {
          this._targetEl.removeEventListener("input", this._inputHandler);
          if (this._incrementEl) {
            this._incrementEl.removeEventListener("click", this._incrementClickHandler);
          }
          if (this._decrementEl) {
            this._decrementEl.removeEventListener("click", this._decrementClickHandler);
          }
          this._initialized = false;
        }
      };
      InputCounter2.prototype.removeInstance = function() {
        instances_default.removeInstance("InputCounter", this._instanceId);
      };
      InputCounter2.prototype.destroyAndRemoveInstance = function() {
        this.destroy();
        this.removeInstance();
      };
      InputCounter2.prototype.getCurrentValue = function() {
        return parseInt(this._targetEl.value) || 0;
      };
      InputCounter2.prototype.increment = function() {
        if (this._options.maxValue !== null && this.getCurrentValue() >= this._options.maxValue) {
          return;
        }
        this._targetEl.value = (this.getCurrentValue() + 1).toString();
        this._options.onIncrement(this);
      };
      InputCounter2.prototype.decrement = function() {
        if (this._options.minValue !== null && this.getCurrentValue() <= this._options.minValue) {
          return;
        }
        this._targetEl.value = (this.getCurrentValue() - 1).toString();
        this._options.onDecrement(this);
      };
      InputCounter2.prototype.updateOnIncrement = function(callback) {
        this._options.onIncrement = callback;
      };
      InputCounter2.prototype.updateOnDecrement = function(callback) {
        this._options.onDecrement = callback;
      };
      return InputCounter2;
    }()
  );
  function initInputCounters() {
    document.querySelectorAll("[data-input-counter]").forEach(function($targetEl) {
      var targetId = $targetEl.id;
      var $incrementEl = document.querySelector('[data-input-counter-increment="' + targetId + '"]');
      var $decrementEl = document.querySelector('[data-input-counter-decrement="' + targetId + '"]');
      var minValue = $targetEl.getAttribute("data-input-counter-min");
      var maxValue = $targetEl.getAttribute("data-input-counter-max");
      if ($targetEl) {
        if (!instances_default.instanceExists("InputCounter", $targetEl.getAttribute("id"))) {
          new InputCounter($targetEl, $incrementEl ? $incrementEl : null, $decrementEl ? $decrementEl : null, {
            minValue: minValue ? parseInt(minValue) : null,
            maxValue: maxValue ? parseInt(maxValue) : null
          });
        }
      } else {
        console.error('The target element with id "'.concat(targetId, '" does not exist. Please check the data-input-counter attribute.'));
      }
    });
  }
  if (typeof window !== "undefined") {
    window.InputCounter = InputCounter;
    window.initInputCounters = initInputCounters;
  }

  // node_modules/flowbite/lib/esm/components/clipboard/index.js
  var __assign13 = function() {
    __assign13 = Object.assign || function(t) {
      for (var s, i = 1, n = arguments.length; i < n; i++) {
        s = arguments[i];
        for (var p in s)
          if (Object.prototype.hasOwnProperty.call(s, p))
            t[p] = s[p];
      }
      return t;
    };
    return __assign13.apply(this, arguments);
  };
  var Default13 = {
    htmlEntities: false,
    contentType: "input",
    onCopy: function() {
    }
  };
  var DefaultInstanceOptions13 = {
    id: null,
    override: true
  };
  var CopyClipboard = (
    /** @class */
    function() {
      function CopyClipboard2(triggerEl, targetEl, options, instanceOptions) {
        if (triggerEl === void 0) {
          triggerEl = null;
        }
        if (targetEl === void 0) {
          targetEl = null;
        }
        if (options === void 0) {
          options = Default13;
        }
        if (instanceOptions === void 0) {
          instanceOptions = DefaultInstanceOptions13;
        }
        this._instanceId = instanceOptions.id ? instanceOptions.id : targetEl.id;
        this._triggerEl = triggerEl;
        this._targetEl = targetEl;
        this._options = __assign13(__assign13({}, Default13), options);
        this._initialized = false;
        this.init();
        instances_default.addInstance("CopyClipboard", this, this._instanceId, instanceOptions.override);
      }
      CopyClipboard2.prototype.init = function() {
        var _this = this;
        if (this._targetEl && this._triggerEl && !this._initialized) {
          this._triggerElClickHandler = function() {
            _this.copy();
          };
          if (this._triggerEl) {
            this._triggerEl.addEventListener("click", this._triggerElClickHandler);
          }
          this._initialized = true;
        }
      };
      CopyClipboard2.prototype.destroy = function() {
        if (this._triggerEl && this._targetEl && this._initialized) {
          if (this._triggerEl) {
            this._triggerEl.removeEventListener("click", this._triggerElClickHandler);
          }
          this._initialized = false;
        }
      };
      CopyClipboard2.prototype.removeInstance = function() {
        instances_default.removeInstance("CopyClipboard", this._instanceId);
      };
      CopyClipboard2.prototype.destroyAndRemoveInstance = function() {
        this.destroy();
        this.removeInstance();
      };
      CopyClipboard2.prototype.getTargetValue = function() {
        if (this._options.contentType === "input") {
          return this._targetEl.value;
        }
        if (this._options.contentType === "innerHTML") {
          return this._targetEl.innerHTML;
        }
        if (this._options.contentType === "textContent") {
          return this._targetEl.textContent.replace(/\s+/g, " ").trim();
        }
      };
      CopyClipboard2.prototype.copy = function() {
        var textToCopy = this.getTargetValue();
        if (this._options.htmlEntities) {
          textToCopy = this.decodeHTML(textToCopy);
        }
        var tempTextArea = document.createElement("textarea");
        tempTextArea.value = textToCopy;
        document.body.appendChild(tempTextArea);
        tempTextArea.select();
        document.execCommand("copy");
        document.body.removeChild(tempTextArea);
        this._options.onCopy(this);
        return textToCopy;
      };
      CopyClipboard2.prototype.decodeHTML = function(html) {
        var textarea = document.createElement("textarea");
        textarea.innerHTML = html;
        return textarea.textContent;
      };
      CopyClipboard2.prototype.updateOnCopyCallback = function(callback) {
        this._options.onCopy = callback;
      };
      return CopyClipboard2;
    }()
  );
  function initCopyClipboards() {
    document.querySelectorAll("[data-copy-to-clipboard-target]").forEach(function($triggerEl) {
      var targetId = $triggerEl.getAttribute("data-copy-to-clipboard-target");
      var $targetEl = document.getElementById(targetId);
      var contentType = $triggerEl.getAttribute("data-copy-to-clipboard-content-type");
      var htmlEntities = $triggerEl.getAttribute("data-copy-to-clipboard-html-entities");
      if ($targetEl) {
        if (!instances_default.instanceExists("CopyClipboard", $targetEl.getAttribute("id"))) {
          new CopyClipboard($triggerEl, $targetEl, {
            htmlEntities: htmlEntities && htmlEntities === "true" ? true : Default13.htmlEntities,
            contentType: contentType ? contentType : Default13.contentType
          });
        }
      } else {
        console.error('The target element with id "'.concat(targetId, '" does not exist. Please check the data-copy-to-clipboard-target attribute.'));
      }
    });
  }
  if (typeof window !== "undefined") {
    window.CopyClipboard = CopyClipboard;
    window.initClipboards = initCopyClipboards;
  }

  // node_modules/flowbite/lib/esm/components/index.js
  function initFlowbite() {
    initAccordions();
    initCollapses();
    initCarousels();
    initDismisses();
    initDropdowns();
    initModals();
    initDrawers();
    initTabs();
    initTooltips();
    initPopovers();
    initDials();
    initInputCounters();
    initCopyClipboards();
  }
  if (typeof window !== "undefined") {
    window.initFlowbite = initFlowbite;
  }

  // node_modules/flowbite/lib/esm/index.js
  var events = new events_default("load", [
    initAccordions,
    initCollapses,
    initCarousels,
    initDismisses,
    initDropdowns,
    initModals,
    initDrawers,
    initTabs,
    initTooltips,
    initPopovers,
    initDials,
    initInputCounters,
    initCopyClipboards
  ]);
  events.init();

  // app/assets/javascripts/controllers/resource_drop_down_controller.js
  var resource_drop_down_controller_default = class extends Controller {
    static targets = ["trigger", "menu"];
    connect() {
      this.dropdown = new dropdown_default(this.menuTarget, this.triggerTarget);
    }
    disconnect() {
      this.dropdown = null;
    }
    toggle() {
      this.dropdown.toggle();
    }
    show() {
      this.dropdown.show();
    }
    hide() {
      this.dropdown.show();
    }
  };

  // app/assets/javascripts/controllers/resource_dismiss_controller.js
  var resource_dismiss_controller_default = class extends Controller {
    static targets = ["trigger", "target"];
    static values = {
      after: Number
    };
    connect() {
      this.dismiss = new dismiss_default(this.targetTarget, this.triggerTarget);
      console.log(this.hasAfterValue);
      console.log(this.afterValue);
      if (this.hasAfterValue && this.afterValue > 0) {
        this.autoDismissTimeout = setTimeout(() => {
          this.hide();
          this.autoDismissTimeout = null;
        }, this.afterValue);
      }
    }
    disconnect() {
      if (this.autoDismissTimeout)
        clearTimeout(this.autoDismissTimeout);
      this.dismiss = null;
      this.autoDismissTimeout = null;
    }
    hide() {
      this.dismiss.hide();
    }
  };

  // app/assets/javascripts/controllers/index.js
  function registerControllers(application) {
    application.register("nested-resource-form-fields", nested_resource_form_fields_controller_default);
    application.register("tab-bar", tab_bar_controller_default);
    application.register("toolbar", toolbar_controller_default);
    application.register("table-search-input", table_search_input_controller_default);
    application.register("table-toolbar", table_toolbar_controller_default);
    application.register("table", table_controller_default);
    application.register("form", form_controller_default);
    application.register("resource-drop-down", resource_drop_down_controller_default);
    application.register("resource-dismiss", resource_dismiss_controller_default);
  }
})();
