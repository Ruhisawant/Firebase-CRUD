import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:intl/intl.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const MyApp());
}

class Task {
  String id;
  String name;
  bool completed;
  String priority;
  DateTime dueDate;

  Task({
    required this.id,
    required this.name,
    required this.completed,
    required this.priority,
    required this.dueDate,
  });

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'completed': completed,
      'priority': priority,
      'dueDate': dueDate.toIso8601String(),
    };
  }

  static Task fromMap(String id, Map<String, dynamic> map) {
    return Task(
      id: id,
      name: map['name'] ?? '',
      completed: map['completed'] ?? false,
      priority: map['priority'] ?? 'Low',
      dueDate: map['dueDate'] != null 
          ? DateTime.parse(map['dueDate']) 
          : DateTime.now(),
    );
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Task Manager',
      home: const TaskListScreen(),
    );
  }
}

class TaskListScreen extends StatefulWidget {
  const TaskListScreen({super.key});

  @override
  TaskListScreenState createState() => TaskListScreenState();
}

class TaskListScreenState extends State<TaskListScreen> {
  final TextEditingController _taskController = TextEditingController();
  String _selectedPriority = 'Medium';
  String _selectedFilter = 'All';
  String _sortBy = 'Priority';
  DateTime _selectedDueDate = DateTime.now().add(const Duration(days: 1));

  // Add task
  Future<void> _addTask() async {
    if (_taskController.text.trim().isNotEmpty) {
      await FirebaseFirestore.instance.collection('tasks').add({
        'name': _taskController.text.trim(),
        'completed': false,
        'priority': _selectedPriority,
        'dueDate': _selectedDueDate.toIso8601String(),
      });
      _taskController.clear();
      
      setState(() {
        _selectedDueDate = DateTime.now().add(const Duration(days: 1));
        _selectedPriority = 'Medium';
      });
    }
  }

  // Update task
  Future<void> _updateTask(Task task) async {
    await FirebaseFirestore.instance.collection('tasks').doc(task.id).update(task.toMap());
  }

  // Toggle complete task
  Future<void> _toggleCompletion(Task task) async {
    task.completed = !task.completed;
    await _updateTask(task);
  }

  // Delete task
  Future<void> _deleteTask(String taskId) async {
    await FirebaseFirestore.instance.collection('tasks').doc(taskId).delete();
  }

  // Fetch task list from Firebase
  Stream<List<Task>> _getTasks() {
    return FirebaseFirestore.instance.collection('tasks').snapshots().map((snapshot) {
      return snapshot.docs.map((doc) => Task.fromMap(doc.id, doc.data())).toList();
    });
  }

  // Sort tasks
  List<Task> _sortTasks(List<Task> tasks) {
    switch (_sortBy) {
      case 'Priority':
        final priorityOrder = {'High': 0, 'Medium': 1, 'Low': 2};
        tasks.sort((a, b) => priorityOrder[a.priority]!.compareTo(priorityOrder[b.priority]!));
        break;
      case 'Due Date':
        tasks.sort((a, b) => a.dueDate.compareTo(b.dueDate));
        break;
      case 'Name':
        tasks.sort((a, b) => a.name.compareTo(b.name));
        break;
      case 'Completion':
        tasks.sort((a, b) => a.completed == b.completed ? 0 : (a.completed ? 1 : -1));
        break;
    }
    return tasks;
  }

  // Filter tasks
  List<Task> _filterTasks(List<Task> tasks) {
    switch (_selectedFilter) {
      case 'Completed':
        return tasks.where((task) => task.completed).toList();
      case 'Incomplete':
        return tasks.where((task) => !task.completed).toList();
      case 'High Priority':
        return tasks.where((task) => task.priority == 'High').toList();
      case 'Due Today':
        final today = DateTime(
          DateTime.now().year,
          DateTime.now().month,
          DateTime.now().day,
        );
        return tasks.where((task) {
          final taskDate = DateTime(
            task.dueDate.year,
            task.dueDate.month,
            task.dueDate.day,
          );
          return taskDate.isAtSameMomentAs(today);
        }).toList();
      case 'Overdue':
        final today = DateTime(
          DateTime.now().year,
          DateTime.now().month,
          DateTime.now().day,
        );
        return tasks.where((task) {
          final taskDate = DateTime(
            task.dueDate.year,
            task.dueDate.month,
            task.dueDate.day,
          );
          return taskDate.isBefore(today) && !task.completed;
        }).toList();
      default:
        return tasks;
    }
  }

  // Select due date
  Future<void> _selectDueDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDueDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null && picked != _selectedDueDate) {
      setState(() {
        _selectedDueDate = picked;
      });
    }
  }

  // Edit task dialog
  void _showEditTaskDialog(Task task) {
    final TextEditingController taskNameController = TextEditingController(text: task.name);
    String priority = task.priority;
    DateTime dueDate = task.dueDate;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Task'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: taskNameController,
                decoration: const InputDecoration(
                  labelText: 'Task Name',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: priority,
                decoration: const InputDecoration(
                  labelText: 'Priority',
                  border: OutlineInputBorder(),
                ),
                items: ['Low', 'Medium', 'High']
                    .map((e) => DropdownMenuItem<String>(value: e, child: Text(e)))
                    .toList(),
                onChanged: (value) {
                  priority = value!;
                },
              ),
              const SizedBox(height: 16),
              InkWell(
                onTap: () async {
                  final DateTime? picked = await showDatePicker(
                    context: context,
                    initialDate: dueDate,
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                  );
                  if (picked != null) {
                    dueDate = picked;
                  }
                },
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Due Date',
                    border: OutlineInputBorder(),
                  ),
                  child: Text(DateFormat('MMM dd, yyyy').format(dueDate)),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              task.name = taskNameController.text.trim();
              task.priority = priority;
              task.dueDate = dueDate;
              _updateTask(task);
              Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Task Manager'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        centerTitle: true,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Card(
              elevation: 3,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Task input area
                    TextField(
                      controller: _taskController,
                      decoration: const InputDecoration(
                        labelText: 'Enter Task',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.task),
                      ),
                    ),
                    const SizedBox(height: 16),

                    Row(
                      children: [
                        // Priority dropdown
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: _selectedPriority,
                            decoration: const InputDecoration(
                              labelText: 'Priority',
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            ),
                            items: ['Low', 'Medium', 'High']
                                .map((e) => DropdownMenuItem<String>(value: e, child: Text(e)))
                                .toList(),
                            onChanged: (value) {
                              setState(() {
                                _selectedPriority = value!;
                              });
                            },
                          ),
                        ),
                        const SizedBox(width: 8),

                        // Due date picker
                        InkWell(
                          onTap: () => _selectDueDate(context),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.calendar_today, size: 18),
                                const SizedBox(width: 4),
                                Text(DateFormat('MMM dd').format(_selectedDueDate)),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Add task button
                    ElevatedButton.icon(
                      onPressed: _addTask,
                      label: const Text('Add Task'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.deepPurple,
                        foregroundColor: Colors.white,
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Row(
                  children: [
                    // Filter dropdown
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _selectedFilter,
                        decoration: const InputDecoration(
                          labelText: 'Filter',
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        ),
                        items: ['All', 'Completed', 'Incomplete', 'High Priority', 'Due Today', 'Overdue']
                            .map((e) => DropdownMenuItem<String>(value: e, child: Text(e)))
                            .toList(),
                        onChanged: (value) {
                          setState(() {
                            _selectedFilter = value!;
                          });
                        },
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Sort dropdown
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _sortBy,
                        decoration: const InputDecoration(
                          labelText: 'Sort By',
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        ),
                        items: ['Priority', 'Due Date', 'Name', 'Completion']
                            .map((e) => DropdownMenuItem<String>(value: e, child: Text(e)))
                            .toList(),
                        onChanged: (value) {
                          setState(() {
                            _sortBy = value!;
                          });
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Task list
          Expanded(
            child: StreamBuilder<List<Task>>(
              stream: _getTasks(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                } else if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.task_alt, size: 64, color: Colors.grey),
                        SizedBox(height: 16),
                        Text(
                          'No tasks available',
                          style: TextStyle(fontSize: 18, color: Colors.grey),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Add a new task to get started',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  );
                } else {
                  List<Task> tasks = snapshot.data!;
                  tasks = _sortTasks(tasks);
                  tasks = _filterTasks(tasks);

                  return ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: tasks.length,
                    itemBuilder: (context, index) {
                      Task task = tasks[index];
                      
                      Color? priorityColor;
                      switch (task.priority) {
                        case 'High':
                          priorityColor = Colors.red.shade50;
                          break;
                        case 'Medium':
                          priorityColor = Colors.orange.shade50;
                          break;
                        case 'Low':
                          priorityColor = Colors.green.shade50;
                          break;
                      }
                      
                      bool isOverdue = task.dueDate.isBefore(DateTime.now()) && !task.completed;
                      
                      return Card(
                        elevation: 2,
                        color: task.completed ? Colors.grey.shade100 : priorityColor,
                        child: ListTile(
                          onTap: () => _showEditTaskDialog(task),
                          leading: Checkbox(
                            value: task.completed,
                            onChanged: (_) {
                              _toggleCompletion(task);
                            },
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                          title: Text(
                            task.name,
                            style: TextStyle(
                              decoration: task.completed ? TextDecoration.lineThrough : null,
                              color: task.completed ? Colors.grey : null,
                            ),
                          ),
                          subtitle: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: task.priority == 'High'
                                      ? Colors.red.shade200
                                      : task.priority == 'Medium'
                                          ? Colors.orange.shade200
                                          : Colors.green.shade200,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  task.priority,
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Icon(
                                Icons.calendar_today,
                                size: 12,
                                color: isOverdue ? Colors.red : Colors.grey,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                DateFormat('MMM dd').format(task.dueDate),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isOverdue ? Colors.red : Colors.grey,
                                  fontWeight: isOverdue ? FontWeight.bold : null,
                                ),
                              ),
                            ],
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit, color: Colors.blue),
                                onPressed: () => _showEditTaskDialog(task),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete, color: Colors.red),
                                onPressed: () => _deleteTask(task.id),
                              ),
                            ],
                          ),
                        ),
                      );
                    }
                  );
                }
              },
            ),
          ),
        ],
      ),
    );
  }
}