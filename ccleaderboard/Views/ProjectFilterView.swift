import SwiftUI

struct ProjectFilterView: View {
    @Binding var selectedProject: String?
    let onApply: () -> Void
    @Environment(\.dismiss) var dismiss
	
    // In a real app, you'd get this list from scanning available projects
    let projects = ["All Projects", "project1", "project2", "project3"]
	
    var body: some View {
        NavigationView {
            List {
                ForEach(projects, id: \.self) { project in
                    HStack {
                        Text(project)
                        Spacer()
                        if (project == "All Projects" && selectedProject == nil) ||
                            (project == selectedProject)
                        {
                            Image(systemName: "checkmark")
                                .foregroundColor(.blue)
                        }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        if project == "All Projects" {
                            selectedProject = nil
                        } else {
                            selectedProject = project
                        }
                    }
                }
            }
            .navigationTitle("Filter by Project")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Apply") {
                        onApply()
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    ProjectFilterView(selectedProject: .constant(nil)) {
        print("Applied filter")
    }
}