import '../models/registry_item.dart';

const keyboardShortcutItems = <RegistryItem>[
  RegistryItem(id: 'global-search', title: 'Global Search Focus', category: 'Navigation', priority: 'P1', status: 'Future', description: 'Keyboard shortcut to focus global search from anywhere in the terminal.', inputs: 'Top bar search and search screen', nextStep: 'Define shortcut behavior after search screen is deeper.'),
  RegistryItem(id: 'sidebar-filter', title: 'Sidebar Filter Focus', category: 'Navigation', priority: 'P1', status: 'Future', description: 'Keyboard shortcut to focus the sidebar tab filter.', inputs: 'Sidebar nav filter', nextStep: 'Add focus node and shortcut mapping later.'),
  RegistryItem(id: 'next-tab', title: 'Next Tab', category: 'Navigation', priority: 'P2', status: 'Future', description: 'Move to the next visible tab in the sidebar.', inputs: 'Filtered tab list and selected index', nextStep: 'Only implement after tab groups/collapse behavior is stable.'),
  RegistryItem(id: 'previous-tab', title: 'Previous Tab', category: 'Navigation', priority: 'P2', status: 'Future', description: 'Move to the previous visible tab in the sidebar.', inputs: 'Filtered tab list and selected index', nextStep: 'Only implement after tab groups/collapse behavior is stable.'),
  RegistryItem(id: 'open-report', title: 'Open Report Builder', category: 'Reports', priority: 'P3', status: 'Future', description: 'Open report builder from entity pages or current selection.', inputs: 'Reports, selected entity state, report templates', nextStep: 'Wait until report builder shell exists.'),
  RegistryItem(id: 'copy-row', title: 'Copy Selected Row', category: 'Tables', priority: 'P3', status: 'Future', description: 'Copy selected table row summary with source metadata.', inputs: 'Data tables and source fields', nextStep: 'Design row selection and copy format.'),
];
