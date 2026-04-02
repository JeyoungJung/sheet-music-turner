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
            .background(DesignTokens.Colors.background)
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
            HStack(spacing: DesignTokens.Spacing.sm) {
                Text(title)
                    .font(DesignTokens.Typography.body)
                    .foregroundColor(DesignTokens.Colors.primaryText)
                    .frame(maxWidth: .infinity, alignment: .leading)

                if isSelected {
                    Image(systemName: "checkmark")
                        .font(DesignTokens.Typography.caption)
                        .foregroundColor(DesignTokens.Colors.accent)
                }
            }
            .padding(.vertical, DesignTokens.Spacing.xs)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(.plain)
        .listRowInsets(EdgeInsets(top: DesignTokens.Spacing.xs, leading: DesignTokens.Spacing.md, bottom: DesignTokens.Spacing.xs, trailing: DesignTokens.Spacing.md))
        .listRowBackground(DesignTokens.Colors.background)
        .listRowSeparator(.hidden)
        .overlay(alignment: .bottom) {
            SwissDivider()
        }
    }
}
