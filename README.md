# VariPhi LMS - Learning Management System

A comprehensive, open-source Learning Management System built on the Frappe Framework. This project provides a complete solution for creating, managing, and delivering online courses with features like live classes, quizzes, assignments, and certifications.

## 🚀 Overview

VariPhi LMS is a full-featured learning management system that enables educational institutions and organizations to create structured learning experiences. Built on Frappe Framework, it combines the power of Python backend with a modern Vue.js frontend.

### Key Features

- **📚 Structured Learning**: Design courses with a 3-level hierarchy (Courses → Chapters → Lessons)
- **🎥 Live Classes**: Group learners into batches and create Zoom live classes directly from the app
- **📝 Quizzes & Assignments**: Create quizzes with single-choice, multiple-choice, or open-ended questions. Instructors can add assignments for PDF/document submissions
- **🏆 Certifications**: Grant certificates upon course completion with built-in certificate templates
- **💳 Payment Integration**: Integrated payment gateway support via the Payments app (Razorpay, Stripe, Braintree, PayPal, PayTM)
- **👥 User Management**: Role-based access control with student, instructor, and admin roles
- **📊 Analytics & Reports**: Track signups, enrollments, and course completion statistics

## 🛠️ Tech Stack

- **Backend**: Python 3.10+ (Frappe Framework)
- **Frontend**: Vue.js, Frappe UI
- **Database**: MariaDB 10.8+
- **Cache/Queue**: Redis 7
- **Web Server**: Gunicorn
- **Real-time**: Socket.IO
- **Build Tools**: esbuild, Vite

## 📋 Prerequisites

- Python 3.10 or higher
- Node.js 18+ and Yarn
- MariaDB 10.8+
- Redis 7
- Git

## 🚀 Quick Start

### Option 1: Docker Setup (Recommended for Development)

The easiest way to get started is using Docker:

```bash
cd frappe-bench/apps/lms/docker

# Build and start all services
docker-compose up -d

# View logs
docker-compose logs -f frappe
```

**Access Points:**
- Web UI: http://localhost:8000
- SocketIO: ws://localhost:9000
- Frontend Dev Server: http://localhost:5173
- MariaDB: localhost:3307 (root password: `123`)
- Redis: localhost:6380

**Default Credentials:**
- Site: `vgi.local`
- Username: `Administrator`
- Password: `admin`

For detailed Docker setup instructions, see [frappe-bench/apps/lms/docker/README.md](frappe-bench/apps/lms/docker/README.md)

### Option 2: Manual Setup

1. **Clone the repository:**
   ```bash
   git clone https://github.com/shivamskr151/test_lms.git
   cd test_lms/frappe-bench
   ```

2. **Set up database:**
   ```bash
   mysql -u root < create_db_user.sql
   ```

3. **Start the bench:**
   ```bash
   bench start
   ```

4. **Run migrations (in a new terminal):**
   ```bash
   bench --site vgi.local migrate
   ```

5. **Access the application:**
   - URL: http://vgi.local:8000 or http://127.0.0.1:8000
   - Username: `Administrator`
   - Password: `admin`

For detailed setup instructions, see [frappe-bench/README.md](frappe-bench/README.md)

## 📁 Project Structure

```
test_lms/
├── frappe-bench/              # Main Frappe Bench directory
│   ├── apps/                  # Frappe applications
│   │   ├── frappe/           # Frappe Framework core
│   │   ├── lms/              # Learning Management System app
│   │   └── payments/         # Payment gateway integrations
│   ├── sites/                 # Site configurations and data
│   │   └── vgi.local/        # Default site
│   ├── config/                # Configuration files
│   ├── logs/                  # Application logs
│   ├── env/                   # Python virtual environment
│   ├── Procfile              # Process definitions
│   └── README.md             # Detailed setup guide
└── README.md                  # This file
```

## 🔧 Development

### Using Bench Management Script

The project includes a convenient management script for common operations:

```bash
cd frappe-bench

# Stop all services
./bench-manage.sh stop

# Check system status
./bench-manage.sh check

# Start services
./bench-manage.sh start

# Restart services
./bench-manage.sh restart

# Fix common issues
./bench-manage.sh fix-env
./bench-manage.sh fix-ui
./bench-manage.sh fix-paths
```

### Frontend Development

```bash
cd frappe-bench/apps/lms

# Install dependencies
yarn install

# Start development server
yarn dev

# Build for production
yarn build
```

### Backend Development

```bash
cd frappe-bench

# Activate virtual environment
source env/bin/activate

# Run migrations
bench --site vgi.local migrate

# Open Python console
bench --site vgi.local console

# Open database console
bench --site vgi.local mariadb
```

## 🗄️ Database Management

### Quick Access

```bash
cd frappe-bench

# Use the access script
./access_database.sh                    # Interactive MySQL shell
./access_database.sh info               # Database information
./access_database.sh tables             # List all tables
./access_database.sh backup             # Create backup
```

### Using Bench Commands

```bash
# Open MariaDB console
bench --site vgi.local mariadb

# Open Python console with DB access
bench --site vgi.local console
```

## 🐳 Docker Development

The Docker setup supports hot-reload for development:

- Source code is mounted as volumes
- Changes reflect immediately without rebuild
- All services run in containers
- Ports are mapped to avoid conflicts with local services

See [frappe-bench/apps/lms/docker/README.md](frappe-bench/apps/lms/docker/README.md) for complete Docker documentation.

## 📦 Applications

### Frappe Framework

The core framework providing:
- Full-stack web application framework
- Built-in admin interface
- Role-based permissions
- REST API
- Customizable forms and views
- Report builder

### LMS (Learning Management System)

**Features:**
- Course creation and management
- Chapter and lesson organization
- Batch management for live classes
- Quiz and assignment system
- Certificate generation
- Student enrollment tracking
- Progress monitoring

### Payments App

Payment gateway integration supporting:
- Razorpay
- Stripe
- Braintree
- PayPal
- PayTM

## 🔐 Default Credentials

**⚠️ Security Warning**: These are default development credentials. Change all passwords before deploying to production!

**Site Access:**
- URL: http://vgi.local:8000
- Username: `Administrator`
- Password: `admin`

**Database:**
- Database: `_2ca05118bd4124f3`
- User: `_2ca05118bd4124f3`
- Password: `vAhQPAHJpRcIsQmi`

## 🐛 Troubleshooting

### Port Already in Use
```bash
./bench-manage.sh stop
```

### Database Connection Error
```bash
mysql -u root < create_db_user.sql
```

### Missing Dependencies
```bash
cd frappe-bench/apps/frappe && yarn install
cd frappe-bench/apps/lms && yarn install
```

### Migration Errors
```bash
bench --site vgi.local migrate --skip-search-index
```

### Docker Issues
```bash
# Check logs
docker-compose logs frappe

# Rebuild from scratch
docker-compose down -v
docker-compose build --no-cache
docker-compose up -d
```

For more troubleshooting tips, see [frappe-bench/README.md](frappe-bench/README.md)

## 📚 Documentation

- [Frappe Framework Documentation](https://docs.frappe.io/framework)
- [LMS Documentation](https://docs.frappe.io/learning)
- [Frappe Cloud](https://frappecloud.com)
- [Discussion Forum](https://discuss.frappe.io/)

## 🤝 Contributing

Contributions are welcome! Please follow these steps:

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add some amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## 📄 License

This project is licensed under the AGPL-3.0 License. See individual app licenses:
- [Frappe License](frappe-bench/apps/frappe/LICENSE)
- [LMS License](frappe-bench/apps/lms/license.txt)
- [Payments License](frappe-bench/apps/payments/license.txt)

## 🔗 Links

- **Repository**: https://github.com/shivamskr151/test_lms
- **Issues**: https://github.com/shivamskr151/test_lms/issues
- **Frappe Framework**: https://frappeframework.com
- **LMS App**: https://github.com/frappe/lms

## 📞 Support

For support and questions:
- Check the [Frappe Discussion Forum](https://discuss.frappe.io/)
- Review the [documentation](https://docs.frappe.io/)
- Open an issue on GitHub

## 🙏 Acknowledgments

- Built on [Frappe Framework](https://frappeframework.com)
- LMS app by [Frappe Technologies](https://frappe.io)
- Payment integrations via Frappe Payments app

---

**Note**: This is a development setup. For production deployment, ensure you:
- Change all default passwords
- Configure proper security settings
- Set up SSL/TLS certificates
- Configure backup strategies
- Review and harden database security
- Set up monitoring and logging

