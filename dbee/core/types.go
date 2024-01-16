package core

import "strings"

type SchemaType int

const (
	SchemaFul SchemaType = iota
	SchemaLess
)

type (
	// FormatterOptions provide various options for formatters
	FormatterOptions struct {
		SchemaType SchemaType
		ChunkStart int
	}

	// Formatter converts header and rows to bytes
	Formatter interface {
		Format(header Header, rows []Row, opts *FormatterOptions) ([]byte, error)
	}
)

type (
	// Row and Header are attributes of IterResult iterator
	Row    []any
	Header []string
    GbProcessed []float32

	// Meta holds metadata
	Meta struct {
		// type of schema (schemaful or schemaless)
		SchemaType SchemaType
	}

	// ResultStream is a result from executed query and has a form of an iterator
	ResultStream interface {
		Meta() *Meta
		Header() Header
		GbProcessed() GbProcessed
		Next() (Row, error)
		HasNext() bool
		Close()
	}
)

type StructureType int

const (
	StructureTypeNone StructureType = iota
	StructureTypeTable
	StructureTypeView
)

func (s StructureType) String() string {
	switch s {
	case StructureTypeNone:
		return ""
	case StructureTypeTable:
		return "table"
	case StructureTypeView:
		return "view"
	default:
		return ""
	}
}

func StructureTypeFromString(s string) StructureType {
	switch strings.ToLower(s) {
	case "table":
		return StructureTypeTable
	case "view":
		return StructureTypeView
	default:
		return StructureTypeNone
	}
}

// Structure represents the structure of a single database
type Structure struct {
	// Name to be displayed
	Name   string
	Schema string
	// Type of layout
	Type StructureType
	// Children layout nodes
	Children []*Structure
}

type Column struct {
	// Column name
	Name string
	// Database data type
	Type string
}
