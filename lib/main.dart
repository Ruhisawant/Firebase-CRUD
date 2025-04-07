import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp();
    runApp(MyApp());
  } catch (e) {
    Text("Firebase initialization failed: $e");
  }
}


class Task {
  String id;
  String name;
  bool completed;
  String priority;
  String dueDate;

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
      'dueDate': dueDate,
    };
  }

  static Task fromMap(String id, Map<String, dynamic> map) {
    return Task(
      id: id,
      name: map['name'],
      completed: map['completed'],
      priority: map['priority'],
      dueDate: map['dueDate'],
    );
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Task Manager',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
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
  final FirebaseAuth _auth = FirebaseAuth.instance;
  String _selectedPriority = 'Low';
  String _selectedFilter = 'All';
  String _sortBy = 'Priority';
  late User _user;

  @override
  void initState() {
    super.initState();

    _auth.authStateChanges().listen((User? user) {
      if (user != null) {
        setState(() {
          _user = user;
        });
      }
    });
  }

  // Adding task
  Future<void> _addTask() async {
    String taskName = _taskController.text.trim();
    if (taskName.isNotEmpty) {
      FirebaseFirestore.instance.collection('tasks').add({
        'name': taskName,
        'completed': false,
        'priority': _selectedPriority,
        'dueDate': DateTime.now().toString(),
        'userId': _user.uid,
      });
      _taskController.clear();
    }
  }

  // Marking task as completed
  Future<void> _toggleCompletion(String taskId, bool completed) async {
    await FirebaseFirestore.instance.collection('tasks').doc(taskId).update({
      'completed': !completed,
    });
  }

  // Deleting task
  Future<void> _deleteTask(String taskId) async {
    await FirebaseFirestore.instance.collection('tasks').doc(taskId).delete();
  }

  // Fetching task list from Firebase
  Stream<List<Task>> _getTasks() {
    if (_auth.currentUser == null) {
      return Stream.value([]);
    }
    
    return FirebaseFirestore.instance
        .collection('tasks')
        .where('userId', isEqualTo: _auth.currentUser!.uid)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => Task.fromMap(doc.id, doc.data()))
          .toList();
    });
  }

  // Sorting tasks
  List<Task> _sortTasks(List<Task> tasks) {
    if (_sortBy == 'Priority') {
      tasks.sort((a, b) => a.priority.compareTo(b.priority));
    } else if (_sortBy == 'Due Date') {
      tasks.sort((a, b) => DateTime.parse(a.dueDate).compareTo(DateTime.parse(b.dueDate)));
    } else if (_sortBy == 'Completion') {
      tasks.sort((a, b) => a.completed ? 1 : -1);
    }
    return tasks;
  }

  // Filtering tasks
  List<Task> _filterTasks(List<Task> tasks) {
    if (_selectedFilter == 'Completed') {
      return tasks.where((task) => task.completed).toList();
    } else if (_selectedFilter == 'Incomplete') {
      return tasks.where((task) => !task.completed).toList();
    } else {
      return tasks;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Task Manager'),
        actions: [
          IconButton(
            icon: Icon(Icons.logout),
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: _taskController,
              decoration: InputDecoration(
                labelText: 'Enter Task',
                border: OutlineInputBorder(),
              ),
            ),
          ),
          Row(
            children: [
              DropdownButton<String>(
                value: _selectedPriority,
                items: ['Low', 'Medium', 'High']
                    .map((e) => DropdownMenuItem<String>(value: e, child: Text(e)))
                    .toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedPriority = value!;
                  });
                },
              ),
              ElevatedButton(
                onPressed: _addTask,
                child: Text('Add'),
              ),
            ],
          ),
          Row(
            children: [
              DropdownButton<String>(
                value: _selectedFilter,
                items: ['All', 'Completed', 'Incomplete']
                    .map((e) => DropdownMenuItem<String>(value: e, child: Text(e)))
                    .toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedFilter = value!;
                  });
                },
              ),
              DropdownButton<String>(
                value: _sortBy,
                items: ['Priority', 'Due Date', 'Completion']
                    .map((e) => DropdownMenuItem<String>(value: e, child: Text(e)))
                    .toList(),
                onChanged: (value) {
                  setState(() {
                    _sortBy = value!;
                  });
                },
              ),
            ],
          ),
          Expanded(
            child: StreamBuilder<List<Task>>(
              stream: _getTasks(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(child: CircularProgressIndicator());
                } else if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return Center(child: Text('No tasks available.'));
                } else {
                  List<Task> tasks = snapshot.data!;
                  tasks = _sortTasks(tasks);
                  tasks = _filterTasks(tasks);

                  return ListView.builder(
                    itemCount: tasks.length,
                    itemBuilder: (context, index) {
                      Task task = tasks[index];
                      return ListTile(
                        title: Text(task.name),
                        subtitle: Text('Priority: ${task.priority}'),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Checkbox(
                              value: task.completed,
                              onChanged: (_) {
                                _toggleCompletion(task.id, task.completed);
                              },
                            ),
                            IconButton(
                              icon: Icon(Icons.delete),
                              onPressed: () {
                                _deleteTask(task.id);
                              },
                            ),
                          ],
                        ),
                      );
                    },
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
