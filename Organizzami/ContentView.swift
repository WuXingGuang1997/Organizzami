import SwiftUI

// Estensione per nascondere la tastiera
#if canImport(UIKit)
extension View {
    func hideKeyboard() {
        UIApplication.shared.sendAction(
            #selector(UIResponder.resignFirstResponder),
            to: nil, from: nil, for: nil
        )
    }
}
#endif

// Modello per ogni task
struct TodoItem: Identifiable, Codable {
    var id = UUID()
    var title: String
    var isCompleted: Bool = false
}

// Modello per una cartella che contiene una lista di task
struct Folder: Identifiable, Codable {
    var id = UUID()
    var name: String
    var items: [TodoItem] = []
}

// ViewModel per gestire le cartelle e i task al loro interno, con persistenza via UserDefaults
class FolderViewModel: ObservableObject {
    @Published var folders: [Folder] = [] {
        didSet {
            saveFolders()
        }
    }
    
    private let foldersKey = "foldersKey"
    
    init() {
        loadFolders()
    }
    
    // Carica le cartelle salvate da UserDefaults
    func loadFolders() {
        guard let data = UserDefaults.standard.data(forKey: foldersKey) else { return }
        if let savedFolders = try? JSONDecoder().decode([Folder].self, from: data) {
            folders = savedFolders
        }
    }
    
    // Salva le cartelle in UserDefaults
    func saveFolders() {
        if let encoded = try? JSONEncoder().encode(folders) {
            UserDefaults.standard.set(encoded, forKey: foldersKey)
        }
    }
    
    // Operazioni sulle cartelle
    func addFolder(name: String) {
        let newFolder = Folder(name: name)
        folders.append(newFolder)
    }
    
    func removeFolder(at offsets: IndexSet) {
        folders.remove(atOffsets: offsets)
    }
    
    // Operazioni sui task in una specifica cartella
    func addTodoItem(to folder: Folder, title: String) {
        guard let index = folders.firstIndex(where: { $0.id == folder.id }) else { return }
        let newItem = TodoItem(title: title)
        folders[index].items.append(newItem)
    }
    
    func removeTodoItems(from folder: Folder, at offsets: IndexSet) {
        guard let index = folders.firstIndex(where: { $0.id == folder.id }) else { return }
        folders[index].items.remove(atOffsets: offsets)
    }
    
    func toggleTodoItem(in folder: Folder, item: TodoItem) {
        guard let folderIndex = folders.firstIndex(where: { $0.id == folder.id }) else { return }
        if let itemIndex = folders[folderIndex].items.firstIndex(where: { $0.id == item.id }) {
            folders[folderIndex].items[itemIndex].isCompleted.toggle()
        }
    }
}

// View per ogni riga della lista di task (stile simile a prima)
struct TodoRowView: View {
    let item: TodoItem
    let toggleAction: () -> Void
    
    var body: some View {
        HStack {
            Image(systemName: item.isCompleted ? "checkmark.circle.fill" : "circle")
                .foregroundColor(item.isCompleted ? .green : .gray)
                .font(.title2)
            Text(item.title)
                .font(.system(size: 18, weight: .medium, design: .rounded))
                .foregroundColor(.primary)
                .strikethrough(item.isCompleted, color: .red)
            Spacer()
        }
        .padding()
        .background(Color.white.opacity(0.8))
        .cornerRadius(10)
        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
        .contentShape(Rectangle()) // Rende l'intera cella tappabile
        .onTapGesture {
            withAnimation {
                toggleAction()
            }
        }
    }
}

// Vista per la lista di task all'interno di una cartella
struct FolderDetailView: View {
    @ObservedObject var viewModel: FolderViewModel
    var folder: Folder
    
    @State private var newTaskTitle = ""
    
    var body: some View {
        ZStack {
            // Sfondo con gradienti
            LinearGradient(gradient: Gradient(colors: [Color.blue.opacity(0.3), Color.purple.opacity(0.3)]),
                           startPoint: .topLeading,
                           endPoint: .bottomTrailing)
                .edgesIgnoringSafeArea(.all)
                .onTapGesture { hideKeyboard() }
            VStack {
                // Sezione per aggiungere un nuovo task
                HStack {
                    TextField("Aggiungi nuovo task...", text: $newTaskTitle)
                        .padding()
                        .background(Color.white)
                        .cornerRadius(10)
                        .shadow(color: .black.opacity(0.1), radius: 3, x: 0, y: 2)
                    Button(action: {
                        guard !newTaskTitle.isEmpty else { return }
                        withAnimation {
                            viewModel.addTodoItem(to: folder, title: newTaskTitle)
                        }
                        newTaskTitle = ""
                        hideKeyboard()
                    }) {
                        Image(systemName: "plus")
                            .foregroundColor(.white)
                            .padding()
                            .background(Color.green)
                            .clipShape(Circle())
                            .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
                    }
                }
                .padding()
                
                // Lista dei task della cartella
                List {
                    ForEach(folder.items) { item in
                        TodoRowView(item: item) {
                            viewModel.toggleTodoItem(in: folder, item: item)
                        }
                        .listRowBackground(Color.clear)
                    }
                    .onDelete { offsets in
                        viewModel.removeTodoItems(from: folder, at: offsets)
                    }
                }
                .listStyle(PlainListStyle())
                .background(Color.clear)
            }
        }
        .navigationTitle(folder.name)
    }
}

// Vista iniziale che mostra la lista di cartelle
struct FoldersListView: View {
    @ObservedObject var viewModel = FolderViewModel()
    @State private var newFolderName = ""
    
    var body: some View {
        NavigationView {
            ZStack {
                // Sfondo con gradienti per le cartelle
                LinearGradient(gradient: Gradient(colors: [Color.orange.opacity(0.3), Color.red.opacity(0.3)]),
                               startPoint: .topLeading,
                               endPoint: .bottomTrailing)
                    .edgesIgnoringSafeArea(.all)
                    .onTapGesture { hideKeyboard() }
                VStack {
                    // Sezione per aggiungere una nuova cartella
                    HStack {
                        TextField("Nuova cartella...", text: $newFolderName)
                            .padding()
                            .background(Color.white)
                            .cornerRadius(10)
                            .shadow(color: .black.opacity(0.1), radius: 3, x: 0, y: 2)
                        Button(action: {
                            guard !newFolderName.isEmpty else { return }
                            withAnimation {
                                viewModel.addFolder(name: newFolderName)
                            }
                            newFolderName = ""
                            hideKeyboard()
                        }) {
                            Image(systemName: "folder.badge.plus")
                                .foregroundColor(.white)
                                .padding()
                                .background(Color.blue)
                                .clipShape(Circle())
                                .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
                        }
                    }
                    .padding()
                    
                    // Lista delle cartelle
                    List {
                        ForEach(viewModel.folders) { folder in
                            NavigationLink(destination: FolderDetailView(viewModel: viewModel, folder: folder)) {
                                Text(folder.name)
                                    .font(.headline)
                                    .padding()
                                    .background(Color.white.opacity(0.8))
                                    .cornerRadius(10)
                                    .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
                            }
                            .listRowBackground(Color.clear)
                        }
                        .onDelete(perform: viewModel.removeFolder)
                    }
                    .listStyle(PlainListStyle())
                    .background(Color.clear)
                }
            }
            .navigationTitle("Organizzami")
        }
    }
}
