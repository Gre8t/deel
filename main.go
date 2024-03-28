package main

import (
	"context"
	"fmt"
	"net"
	"net/http"
	"os"
	"strconv"
	"strings"

	"github.com/go-redis/redis/v8"
)

var ctx = context.Background()
var db *redis.Client

func reverseString(s string) string {
	runes := []rune(s)
	for i, j := 0, len(runes)-1; i < j; i, j = i+1, j-1 {
		runes[i], runes[j] = runes[j], runes[i]
	}
	return string(runes)
}

func reverseIP(ip string) string {
	parts := strings.Split(ip, ".")
	for i, part := range parts {
		parts[i] = reverseString(part) 
	}
	
	for i, j := 0, len(parts)-1; i < j; i, j = i+1, j-1 {
		parts[i], parts[j] = parts[j], parts[i]
	}
	return strings.Join(parts, ".")
}

func handleReverseIP(w http.ResponseWriter, r *http.Request) {
	ip, _, _ := net.SplitHostPort(r.RemoteAddr)
	val, err := db.Get(ctx, ip).Result()
	if err == redis.Nil {
		// IP not found, reverse and store it
		reversedIP := reverseIP(ip)
		err = db.Set(ctx, ip, reversedIP, 0).Err()
		if err != nil {
			http.Error(w, "Error storing IP", http.StatusInternalServerError)
			return
		}
		fmt.Fprintf(w, "Reversed IP: %s", reversedIP)
	} else if err != nil {
		http.Error(w, "Error retrieving IP", http.StatusInternalServerError)
	} else {
		fmt.Fprintf(w, "Reversed IP (cached): %s", val)
	}
}

func handleGetAllIPs(w http.ResponseWriter, r *http.Request) {
	keys, err := db.Keys(ctx, "*").Result()
	if err != nil {
		http.Error(w, "Error fetching keys", http.StatusInternalServerError)
		return
	}
	for _, key := range keys {
		val, err := db.Get(ctx, key).Result()
		if err != nil {
			http.Error(w, "Error fetching IP values", http.StatusInternalServerError)
			return
		}
		fmt.Fprintf(w, "IP: %s, Reversed IP: %s\n", key, val)
	}
}

func setupRoutes() {
	http.HandleFunc("/", handleReverseIP)
	http.HandleFunc("/get-all", handleGetAllIPs)
}

func main() {
	redisAddr := os.Getenv("REDIS_HOST") + ":" + os.Getenv("REDIS_PORT")
	redisPassword := os.Getenv("REDIS_PASSWORD")
	redisDB, err := strconv.Atoi(os.Getenv("REDIS_DB"))
	if err != nil {
		redisDB = 0 
	}

	db = redis.NewClient(&redis.Options{
		Addr:     redisAddr,
		Password: redisPassword,
		DB:       redisDB,
	})

	pong, err := db.Ping(ctx).Result()
	if err != nil {
		fmt.Println("Failed to connect to Redis:", err)
		os.Exit(1) 
	}

	fmt.Println("Redis connection successful:", pong)
	setupRoutes()
	fmt.Println("Server is running on port 80")
	http.ListenAndServe(":80", nil)
}
