import SwiftUI

struct FolderPickerSheet: View {
    let folders: [Folder]
    let selectedFolder: Folder?
    let onSelect: (Folder?) -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                pickerRow(title: "Unfiled", isSelected: selectedFolder == nil) {
                    onSelect(nil)
                    dismiss()
                }

                ForEach(folders) { folder in
                    pickerRow(title: folder.name, isSelected: selectedFolder?.id == folder.id) {
                        onSelect(folder)
                        dismiss()
                    }
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(Theme.Colors.canvas)
            .navigationTitle("Move To")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func pickerRow(title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: Theme.Spacing.sm) {
                Text(title)
                    .font(Theme.body())
                    .foregroundColor(Theme.Colors.textPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                if isSelected {
                    Image(systemName: "checkmark")
                        .font(Theme.caption())
                        .foregroundColor(Theme.Colors.gold)
                }
            }
            .padding(.vertical, Theme.Spacing.xs)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(.plain)
        .listRowInsets(EdgeInsets(top: Theme.Spacing.xs, leading: Theme.Spacing.md, bottom: Theme.Spacing.xs, trailing: Theme.Spacing.md))
        .listRowBackground(Theme.Colors.canvas)
        .listRowSeparator(.hidden)
        .overlay(alignment: .bottom) {
            SwissDivider()
        }
    }
}
