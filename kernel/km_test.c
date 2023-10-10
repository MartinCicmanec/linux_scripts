#include <linux/init.h>
#include <linux/module.h>
#include <linux/kernel.h>
#include <linux/fs.h>
#include <linux/uaccess.h>

#define DEVICE_NAME "rickroll"

MODULE_LICENSE("GPL");

static int dev_open(struct inode*, struct file*);
static int dev_release(struct inode*, struct file*);
static ssize_t dev_read(struct file*, char*, size_t, loff_t*);
static ssize_t dev_write(struct file*, const char*, size_t, loff_t*);

static struct file_operations fops = {
    .open = dev_open,
    .read = dev_read,
    .write = dev_write,
    .release = dev_release,
};

static int major;

static int __init km_test_init(void) {
    major = register_chrdev(0, DEVICE_NAME, &fops);

    if (major < 0) {
        printk(KERN_ALERT "Custom Kernel module load failed.\n");
        return major;
    }

    printk(KERN_INFO "Custom Kernel module has been loaded: %d\n", major);
    return 0;
}

static void __exit km_test_exit(void) {
    unregister_chrdev(major, DEVICE_NAME);
    printk(KERN_INFO "Custom Kernel module has been unloaded.\n");
}

static int dev_open(struct inode *inodep, struct file *filep) {
    printk(KERN_INFO "Custom Kernel module device opened.\n");
    return 0;
}

static int dev_release(struct inode *inodep, struct file *filep) {
    printk(KERN_INFO "Custom Kernel module device closed.\n");
    return 0;
}
static ssize_t dev_read(struct file *filep, char *buffer, size_t len, loff_t *offset) {
    int errors = 0;
    char *message = "never gonna give you up, never gonna let you down ... ";
    int message_len = strlen(message);

    errors = copy_to_user(buffer, message, message_len);
    return errors == 0 ? message_len : -EFAULT;
}

static ssize_t dev_write(struct file *filep, const char *buffer, size_t len, loff_t *offset) {
    printk(KERN_INFO "Custom Kernel module device is read only.\n");
    return -EFAULT;
}


module_init(km_test_init);
module_exit(km_test_exit);