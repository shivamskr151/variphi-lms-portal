<template>
	<img
		:src="logoPath"
		alt="VariPhi Logo"
		class="lms-logo"
	/>
</template>

<script setup>
// Use a computed property to avoid Vite trying to resolve the path during build
const logoPath = '/assets/lms/images/lms-logo.png'
</script>
