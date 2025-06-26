# Refactor Candidates

This document outlines parts of the SnapAGram codebase that are good candidates for refactoring. The goal of these suggestions is to improve code quality, maintainability, testability, and scalability.

---

## 1. `UserDatabaseService` (`lib/services/user_database_service.dart`)

### Why it needs a refactor:

The `UserDatabaseService` has grown too large and handles multiple, distinct responsibilities, making it a "kitchen sink" for user-related database operations.

-   **Poor Cohesion & High Coupling**: It manages user data (CRUD), handle generation/validation, user search, and connection/friendship logic. These are separate concerns.
-   **Low Readability**: At nearly 1000 lines of code, understanding and navigating this file is difficult and time-consuming.
-   **Difficult to Test**: The class relies exclusively on static methods, which complicates unit testing. It's hard to test individual components in isolation or mock dependencies.
-   **Inconsistent Error Handling**: The service mixes `try-catch` blocks that `throw Exception` with others that silently fail and print to the console.

### Proposed Changes:

The `UserDatabaseService` should be broken down into smaller, more focused services that follow the Single Responsibility Principle (SRP).

-   **`UserService`**: Would handle core user profile data (e.g., `createUserProfile`, `getUserById`, `updateUserProfile`).
-   **`HandleService`**: Would be dedicated to managing user handles (`generateUniqueHandle`, `isHandleAvailable`, `getUserByHandle`). This encapsulates the logic for handle creation and validation.
-   **`UserSearchService`**: Would contain the logic for searching users (`searchUsers`). This could be optimized independently of other user-related services.
-   **`ConnectionService`**: Would manage the social graph (e.g., `sendConnectionRequest`, `acceptConnectionRequest`, `getUserConnections`).

**Additionally:**

-   **Switch to Instance Methods**: Convert static methods to instance methods. This will allow for easier testing and dependency injection.
-   **Consistent Error Handling**: Implement a uniform error handling strategy across all new services.

---

## 2. `AppServiceManager` (`lib/services/app_service_manager.dart`)

### Why it needs a refactor:

`AppServiceManager` acts as a "God Object" by providing a single access point to nearly all other services. This is a common anti-pattern.

-   **Hides Dependencies**: When a widget uses `AppServiceManager`, it's not clear which specific services it actually depends on. This makes the code harder to reason about. For example, a widget might only need `AuthService`, but by using `AppServiceManager`, it gains access to `StoryDatabaseService`, `ChatDatabaseService`, and more.
-   **Violates Single Responsibility Principle (SRP)**: It has methods for user operations, story operations, and chat operations, making it a "do-everything" object.
-   **Complicates Testing**: To test a widget that depends on `AppServiceManager`, you need to provide a mock for the entire manager, which is complex. It would be much simpler to mock only the specific service that the widget needs.
-   **High Coupling**: It is tightly coupled to all the services it manages.

### Proposed Changes:

Instead of using a single service manager, we should use a proper dependency injection (DI) solution to provide services directly to the widgets that need them.

-   **Use a Service Locator or DI Package**: Introduce a service locator like `get_it` or a DI framework like `Riverpod`.
-   **Register Services**: Each service (`AuthService`, `UserService`, `StoryDatabaseService`, etc.) would be registered with the DI container.
-   **Provide Services to the Widget Tree**: Widgets would then declare their dependency on specific services, and the DI solution would provide them.

**Example using `Provider`**:

Instead of:

```dart
// In a widget
onTap: () {
  AppServiceManager().createStory(...);
}
```

The refactored code would look like this:

```dart
// In a widget build method
final storyService = Provider.of<StoryDatabaseService>(context, listen: false);

// In the onTap callback
onTap: () {
  storyService.createStory(...);
}
```

This makes dependencies explicit, improves testability, and decouples our widgets from a monolithic service manager.

---

## Refactoring Progress

### ✅ Completed Refactors

#### 1. UserDatabaseService Split ✅

**Status: COMPLETED**

The large `UserDatabaseService` has been successfully split into four focused services:

- **`HandleService`** (`lib/services/handle_service.dart`): Manages user handle generation, validation, and reservation
- **`UserService`** (`lib/services/user_service.dart`): Handles core user profile operations (CRUD)
- **`ConnectionService`** (`lib/services/connection_service.dart`): Manages social connections and friend requests
- **`UserSearchService`** (`lib/services/user_search_service.dart`): Contains user search functionality with advanced filtering

**Benefits achieved:**
- Each service now has a single responsibility
- Easier to test individual components
- Better code organization and maintainability
- Reduced coupling between different user-related operations

#### 2. Riverpod Integration ✅

**Status: COMPLETED**

Successfully integrated Riverpod as the dependency injection solution:

- Added `flutter_riverpod`, `riverpod_annotation`, and `riverpod_generator` dependencies
- Created Riverpod providers for all new services using code generation
- Updated `main.dart` to use `ProviderScope` and `ConsumerWidget`
- Converted `AuthService` to work with Riverpod providers

**Benefits achieved:**
- Explicit dependency declarations
- Better testability through easy mocking
- Improved performance with automatic dependency tracking
- Type-safe dependency injection

### 🔄 Next Steps

#### 3. AppServiceManager Deprecation

**Status: IN PROGRESS**

The `AppServiceManager` still exists but should be gradually phased out in favor of direct service injection:

- Update existing widgets to use individual service providers instead of `AppServiceManager`
- Remove deprecated methods from `AppServiceManager`
- Eventually delete the `AppServiceManager` class entirely

#### 4. Update Existing Code

**Status: PENDING**

Existing screens and widgets still reference the old `UserDatabaseService` and `AppServiceManager`:

- Update all imports to use the new split services
- Replace `UserDatabaseService` static calls with injected service instances
- Update widgets to use Riverpod's `ConsumerWidget` or `Consumer` where needed

### 📋 Migration Checklist

- [x] Create `HandleService`
- [x] Create `UserService` 
- [x] Create `ConnectionService`
- [x] Create `UserSearchService`
- [x] Add Riverpod dependencies
- [x] Create Riverpod providers for all services
- [x] Update `main.dart` to use Riverpod
- [ ] Update authentication screens to use new services
- [ ] Update home and profile screens
- [ ] Update friends/connections screens
- [ ] Update search functionality
- [ ] Remove `AppServiceManager` usage
- [ ] Delete deprecated `UserDatabaseService`
- [ ] Delete `AppServiceManager` 