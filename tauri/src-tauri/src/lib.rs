mod models;
mod db;
mod commands;

use db::DbState;
use std::sync::Mutex;
use tauri::Manager;

#[cfg_attr(mobile, tauri::mobile_entry_point)]
pub fn run() {
    tauri::Builder::default()
        .plugin(tauri_plugin_shell::init())
        .plugin(tauri_plugin_dialog::init())
        .plugin(tauri_plugin_fs::init())
        .setup(|app| {
            let app_dir = app.path().app_data_dir()
                .expect("Failed to get app data dir");
            std::fs::create_dir_all(&app_dir).expect("Failed to create app data dir");
            let db_path = app_dir.join("api_signals.db");
            let conn = db::init_db(db_path.to_str().expect("Invalid db path"))
                .expect("Failed to initialize database");
            app.manage(DbState(Mutex::new(conn)));
            Ok(())
        })
        .invoke_handler(tauri::generate_handler![
            // Workspace
            commands::workspace::get_workspaces,
            commands::workspace::create_workspace,
            commands::workspace::update_workspace,
            commands::workspace::delete_workspace,
            // Collection
            commands::collection::get_collections,
            commands::collection::create_collection,
            commands::collection::update_collection,
            commands::collection::delete_collection,
            commands::collection::reorder_collection,
            // Request
            commands::request::get_requests,
            commands::request::get_all_requests,
            commands::request::create_request,
            commands::request::update_request,
            commands::request::delete_request,
            commands::request::duplicate_request,
            // Environment
            commands::environment::get_environments,
            commands::environment::create_environment,
            commands::environment::update_environment,
            commands::environment::delete_environment,
            commands::environment::set_active_environment,
            // History
            commands::history::get_history,
            commands::history::add_history_entry,
            commands::history::clear_history,
            commands::history::delete_history_entry,
            // HTTP
            commands::http::execute_request,
            // Mock server
            commands::mock_server::get_mock_routes,
            commands::mock_server::add_mock_route,
            commands::mock_server::update_mock_route,
            commands::mock_server::delete_mock_route,
            commands::mock_server::start_mock_server,
            commands::mock_server::stop_mock_server,
            commands::mock_server::get_mock_server_status,
            // Import/Export
            commands::import_export::import_curl,
            commands::import_export::export_curl,
            commands::import_export::import_postman,
            commands::import_export::export_postman,
            commands::import_export::import_har,
            commands::import_export::import_openapi,
            // Snippets
            commands::snippet::generate_snippet,
            // Settings
            commands::settings::get_settings,
            commands::settings::update_settings,
        ])
        .run(tauri::generate_context!())
        .expect("error while running tauri application");
}
